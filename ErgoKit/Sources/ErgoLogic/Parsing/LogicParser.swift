//
//  LogicParser.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import Foundation

/// Premises are separated by commas or new lines. The conclusion comes after ∴, ⊢ or ⊨,
/// or before ∵. Without any of those every line is checked on its own.
///
/// Binding, tightest first: ¬ □ ◇ ∀ ∃, then ∧, then ∨ ⊕, then → (groups right), then ↔ ⇔.
public struct LogicArgument: Equatable, Sendable {
	public var premises: [LogicStatement] = []
	public var conclusion: LogicStatement?

	public init(premises: [LogicStatement] = [], conclusion: LogicStatement? = nil) {
		self.premises = premises
		self.conclusion = conclusion
	}
}

public struct LogicStatement: Equatable, Sendable {
	public let formula: LogicFormula

	/// Entry indices in the editor
	public let range: Range<Int>

	public init(formula: LogicFormula, range: Range<Int>) {
		self.formula = formula
		self.range = range
	}
}

public struct LogicDiagnostic: Equatable, Sendable, Error {
	public let problem: LogicProblem

	/// Entry indices in the editor, so it can be underlined later
	public let range: Range<Int>

	/// The text just stops partway through, which is probably still being typed rather than a mistake
	public var isUnfinished = false

	/// A likely fix, when the mistake is easy to guess
	public var fix: LogicFix?

	public init(problem: LogicProblem, range: Range<Int>, isUnfinished: Bool = false, fix: LogicFix? = nil) {
		self.problem = problem
		self.range = range
		self.isUnfinished = isUnfinished
		self.fix = fix
	}
}

/// Swaps `range` for `replacement`, in entry indices
public struct LogicFix: Equatable, Sendable {
	public let range: Range<Int>
	public let replacement: [LogicKeyboardEntry]

	public init(range: Range<Int>, replacement: [LogicKeyboardEntry]) {
		self.range = range
		self.replacement = replacement
	}
}

public enum LogicProblem: Equatable, Sendable {
	case expectedFormula(after: LogicKeyboardEntry?)
	case missingConnective(before: LogicKeyboardEntry)
	case unexpected(LogicKeyboardEntry)
	case unclosed(LogicKeyboardEntry)
	case mismatched(open: LogicKeyboardEntry, close: LogicKeyboardEntry)
	case expectedLetter(after: LogicKeyboardEntry)

	/// A set term like X∪Y standing where a statement should be. Carries the ∪, ∩ or ∅ that made it a set.
	case setWithoutRelation(LogicKeyboardEntry)

	case extraArgumentMarker(LogicKeyboardEntry)
	case missingConclusion(marker: LogicKeyboardEntry)
	case extraConclusions(marker: LogicKeyboardEntry)
	case misplacedEndMarker
	case unsupported(LogicKeyboardEntry)
}

public struct LogicParse: Equatable, Sendable {
	public var argument = LogicArgument()
	public var diagnostics: [LogicDiagnostic] = []

	/// The marker that split premises from the conclusion, if any
	public var marker: LogicKeyboardEntry?
}

public enum LogicParser {
	private enum Side {
		case before, after
	}

	private struct Segment {
		let range: Range<Int>
		let side: Side
	}

	public static func parse(_ entries: [LogicKeyboardEntry]) -> LogicParse {
		var parse = LogicParse()
		var segments: [Segment] = []
		var start = 0
		var depth = 0
		var side = Side.before

		func close(at index: Int) {
			if start < index {
				segments.append(Segment(range: start ..< index, side: side))
			}
			start = index + 1
		}

		for (index, entry) in entries.enumerated() {
			switch entry {
				case .delimiter("("), .delimiter("["):
					depth += 1

				case .delimiter(")"), .delimiter("]"):
					depth = max(depth - 1, 0)

				case .delimiter(","):
					if depth == 0 {
						close(at: index)
					}

				case .delimiter("\n"):
					depth = 0
					close(at: index)

				case .symbol("∴"), .symbol("⊢"), .symbol("⊨"), .symbol("∵"):
					depth = 0
					close(at: index)

					if parse.marker == nil {
						parse.marker = entry
						side = .after
					} else {
						parse.diagnostics.append(LogicDiagnostic(problem: .extraArgumentMarker(entry), range: index ..< index + 1))
					}

				case .symbol("∎"):
					close(at: index)

					if entries[(index + 1)...].contains(where: { $0 != .delimiter("\n") }) {
						parse.diagnostics.append(LogicDiagnostic(problem: .misplacedEndMarker, range: index ..< index + 1))
					}

				default:
					break
			}
		}
		close(at: entries.count)

		// Already reported, the conclusion count would just repeat it
		let hasExtraMarker = parse.diagnostics.contains { diagnostic in
			if case .extraArgumentMarker = diagnostic.problem {
				return true
			}
			return false
		}

		var before: [LogicStatement] = []
		var after: [LogicStatement] = []
		var failedSides: Set<Side> = []

		// Where the text really ends, ignoring trailing new lines
		let end = (entries.lastIndex { $0 != .delimiter("\n") } ?? -1) + 1

		for segment in segments {
			if let definition = entries[segment.range].firstIndex(of: .symbol("≔")) {
				parse.diagnostics.append(LogicDiagnostic(problem: .unsupported(.symbol("≔")), range: definition ..< definition + 1))
				continue
			}

			var parser = FormulaParser(entries: entries, range: segment.range)
			do {
				let statement = try LogicStatement(formula: parser.parseStatement(), range: segment.range)
				switch segment.side {
					case .before:
						before.append(statement)
					case .after:
						after.append(statement)
				}
			} catch var diagnostic as LogicDiagnostic {
				diagnostic.isUnfinished = isUnfinished(diagnostic, segment: segment.range, end: end)
				diagnostic.fix = fix(for: diagnostic, in: entries)
				parse.diagnostics.append(diagnostic)
				failedSides.insert(segment.side)
			} catch {}
		}

		switch parse.marker {
			case nil:
				parse.argument.premises = before

			case .symbol("∵"):
				parse.argument.conclusion = before.first
				parse.argument.premises = after
				// A conclusion that didn't parse was already reported, so don't also call it missing
				if before.count != 1, !hasExtraMarker, !failedSides.contains(.before) {
					parse.diagnostics.append(conclusionDiagnostic(count: before.count, entries: entries, end: end))
				}

			default:
				parse.argument.premises = before
				parse.argument.conclusion = after.first
				if after.count != 1, !hasExtraMarker, !failedSides.contains(.after) {
					parse.diagnostics.append(conclusionDiagnostic(count: after.count, entries: entries, end: end))
				}
		}

		return parse
	}

	private static func conclusionDiagnostic(count: Int, entries: [LogicKeyboardEntry], end: Int) -> LogicDiagnostic {
		let index = entries.firstIndex { [.symbol("∴"), .symbol("⊢"), .symbol("⊨"), .symbol("∵")].contains($0) } ?? 0
		let marker = entries[index]

		guard count == 0 else {
			return LogicDiagnostic(problem: .extraConclusions(marker: marker), range: index ..< index + 1)
		}

		// Just typed ∴ and haven't got to the conclusion yet
		return LogicDiagnostic(
			problem: .missingConclusion(marker: marker),
			range: index ..< index + 1,
			isUnfinished: marker != .symbol("∵") && index + 1 == end
		)
	}

	/// Only problems at the very end of the text, where typing more would fix them
	private static func isUnfinished(_ diagnostic: LogicDiagnostic, segment: Range<Int>, end: Int) -> Bool {
		switch diagnostic.problem {
			case .unclosed:
				segment.upperBound >= end
			case .expectedFormula, .expectedLetter, .setWithoutRelation, .unexpected(.symbol("∪")), .unexpected(.symbol("∩")):
				diagnostic.range.upperBound >= end
			default:
				false
		}
	}

	private static func fix(for diagnostic: LogicDiagnostic, in entries: [LogicKeyboardEntry]) -> LogicFix? {
		let range = diagnostic.range

		switch diagnostic.problem {
			// ∪ and ∩ look a lot like ∨ and ∧
			case .setWithoutRelation:
				guard !entries[range].contains(.symbol("∅")) else { return nil }
				return LogicFix(range: range, replacement: entries[range].map { entry in
					switch entry {
						case .symbol("∪"): .symbol("∨")
						case .symbol("∩"): .symbol("∧")
						default: entry
					}
				})

			case .unexpected(.symbol("∪")):
				return LogicFix(range: range, replacement: [.symbol("∨")])

			case .unexpected(.symbol("∩")):
				return LogicFix(range: range, replacement: [.symbol("∧")])

			// = and ≠ between whole statements
			case .unexpected(.symbol("=")):
				return LogicFix(range: range, replacement: [.symbol("↔")])

			case .unexpected(.symbol("≠")):
				return LogicFix(range: range, replacement: [.symbol("⊕")])

			case .unexpected(.delimiter(")")), .unexpected(.delimiter("]")):
				return LogicFix(range: range, replacement: [])

			case let .mismatched(open, _):
				return LogicFix(range: range, replacement: [open == .delimiter("(") ? .delimiter(")") : .delimiter("]")])

			default:
				return nil
		}
	}
}

/// Recursive descent over one statement
private struct FormulaParser {
	let entries: [LogicKeyboardEntry]
	let range: Range<Int>
	var index: Int

	init(entries: [LogicKeyboardEntry], range: Range<Int>) {
		self.entries = entries
		self.range = range
		index = range.lowerBound
	}

	private var current: LogicKeyboardEntry? {
		index < range.upperBound ? entries[index] : nil
	}

	private var next: LogicKeyboardEntry? {
		index + 1 < range.upperBound ? entries[index + 1] : nil
	}

	private var previous: LogicKeyboardEntry? {
		index > range.lowerBound ? entries[index - 1] : nil
	}

	private func failure(_ problem: LogicProblem, at position: Int? = nil) -> LogicDiagnostic {
		let position = min(position ?? index, max(range.upperBound - 1, range.lowerBound))
		return LogicDiagnostic(problem: problem, range: position ..< position + 1)
	}

	mutating func parseStatement() throws -> LogicFormula {
		let formula = try biconditional()

		if let current {
			switch current {
				case .delimiter(")"), .delimiter("]"):
					throw failure(.unexpected(current))
				case .variable, .symbol("⊤"), .symbol("∅"), .delimiter("("), .delimiter("["),
				     .symbol("¬"), .symbol("□"), .symbol("◇"), .symbol("∀"), .symbol("∃"):
					throw failure(.missingConnective(before: current))
				default:
					throw failure(.unexpected(current))
			}
		}

		return formula
	}

	private mutating func biconditional() throws -> LogicFormula {
		var left = try implication()
		while current == .symbol("↔") || current == .symbol("⇔") {
			index += 1
			left = try .iff(left, implication())
		}
		return left
	}

	private mutating func implication() throws -> LogicFormula {
		let left = try disjunction()
		guard current == .symbol("→") else { return left }
		index += 1
		return try .implies(left, implication())
	}

	private mutating func disjunction() throws -> LogicFormula {
		var left = try conjunction()
		while let current, current == .symbol("∨") || current == .symbol("⊕") {
			index += 1
			let right = try conjunction()
			left = current == .symbol("∨") ? .or(left, right) : .xor(left, right)
		}
		return left
	}

	private mutating func conjunction() throws -> LogicFormula {
		var left = try unary()
		while current == .symbol("∧") {
			index += 1
			left = try .and(left, unary())
		}
		return left
	}

	private mutating func unary() throws -> LogicFormula {
		switch current {
			case .symbol("¬"):
				index += 1
				return try .not(unary())

			case .symbol("□"):
				index += 1
				return try .necessarily(unary())

			case .symbol("◇"):
				index += 1
				return try .possibly(unary())

			case let .some(quantifier) where quantifier == .symbol("∀") || quantifier == .symbol("∃"):
				index += 1
				guard case let .variable(slot) = current else {
					throw failure(.expectedLetter(after: quantifier), at: index - 1)
				}
				index += 1
				let body = try unary()
				return quantifier == .symbol("∀") ? .forAll(slot, body) : .exists(slot, body)

			default:
				return try primary()
		}
	}

	private mutating func primary() throws -> LogicFormula {
		guard let current else {
			throw failure(.expectedFormula(after: previous), at: index - 1)
		}

		switch current {
			case .symbol("⊤"):
				index += 1
				return .truth

			case .delimiter("("), .delimiter("["):
				let open = index
				index += 1
				let inner = try biconditional()
				let expected: LogicKeyboardEntry = current == .delimiter("(") ? .delimiter(")") : .delimiter("]")

				guard let close = self.current else {
					throw failure(.unclosed(current), at: open)
				}
				guard close == expected else {
					if close == .delimiter(")") || close == .delimiter("]") {
						throw failure(.mismatched(open: current, close: close))
					}
					if close == .delimiter(",") {
						throw failure(.unexpected(close))
					}
					throw failure(.missingConnective(before: close))
				}

				index += 1
				return inner

			case let .variable(slot) where next == .delimiter("("):
				index += 2
				return try .predicate(slot, arguments(open: index - 1))

			case .variable, .symbol("∅"):
				let start = index
				let left = term()

				if let relationEntry = self.current, let relation = LogicRelation(relationEntry) {
					index += 1
					guard let right = termIfPresent() else {
						if let unexpected = self.current {
							throw failure(.unexpected(unexpected))
						}
						throw failure(.expectedFormula(after: relationEntry), at: index - 1)
					}
					return .relation(relation, left, right)
				}

				if case let .variable(slot) = left {
					return .atom(slot)
				}
				let set = entries[start ..< index].first { $0 == .symbol("∪") || $0 == .symbol("∩") } ?? .symbol("∅")
				throw LogicDiagnostic(problem: .setWithoutRelation(set), range: start ..< index)

			case .symbol("∧"), .symbol("∨"), .symbol("⊕"), .symbol("→"), .symbol("↔"), .symbol("⇔"):
				if previous == nil {
					throw failure(.unexpected(current))
				}
				throw failure(.expectedFormula(after: previous), at: index - 1)

			case .delimiter(")"), .delimiter("]"):
				if previous == nil {
					throw failure(.unexpected(current))
				}
				throw failure(.expectedFormula(after: previous), at: index - 1)

			case .symbol("≠"), .symbol("="), .symbol("∈"), .symbol("∉"), .symbol("⊂"), .symbol("⊆"), .symbol("∪"), .symbol("∩"):
				throw failure(.unexpected(current))

			default:
				throw failure(.unexpected(current))
		}
	}

	/// After `P(`, reads `X, Y)`
	private mutating func arguments(open: Int) throws -> [LogicTerm] {
		var terms: [LogicTerm] = []

		while true {
			guard let term = termIfPresent() else {
				guard let current else {
					throw failure(.unclosed(.delimiter("(")), at: open)
				}
				// P() or P(X,)
				if current == .delimiter(")"), let previous {
					throw failure(.expectedLetter(after: previous), at: index - 1)
				}
				throw failure(.unexpected(current))
			}
			terms.append(term)

			switch current {
				case .delimiter(","):
					index += 1
				case .delimiter(")"):
					index += 1
					return terms
				case nil:
					throw failure(.unclosed(.delimiter("(")), at: open)
				case let .some(entry):
					throw failure(.unexpected(entry))
			}
		}
	}

	private mutating func termIfPresent() -> LogicTerm? {
		switch current {
			case .variable, .symbol("∅"):
				term()
			default:
				nil
		}
	}

	/// Letters and ∅, joined left to right by ∪ and ∩. Only call when the current entry starts a term.
	private mutating func term() -> LogicTerm {
		var left = termPrimary()

		while let current, current == .symbol("∪") || current == .symbol("∩") {
			guard let right = peekTermPrimary(at: index + 1) else { break }
			index += 2
			left = current == .symbol("∪") ? .union(left, right) : .intersection(left, right)
		}

		return left
	}

	private mutating func termPrimary() -> LogicTerm {
		let term = peekTermPrimary(at: index) ?? .emptySet
		index += 1
		return term
	}

	private func peekTermPrimary(at position: Int) -> LogicTerm? {
		guard position < range.upperBound else { return nil }

		switch entries[position] {
			case let .variable(slot):
				return .variable(slot)
			case .symbol("∅"):
				return .emptySet
			default:
				return nil
		}
	}
}
