//
//  ArgumentText.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

public enum ArgumentTextKind: Sendable {
	case english
	case logic
}

public enum ArgumentTextProblem: Equatable, Sendable, Error {
	case missingConclusion
	case multipleConclusions

	/// ∵ writes the conclusion first, which a line per statement can't show
	case unsupportedMarker(String)
	case tooManyStatements(limit: Int, found: Int)

	public var message: String {
		switch self {
			case .missingConclusion:
				"Expected a conclusion after the marker, found nothing"
			case .multipleConclusions:
				"Expected one conclusion, found several"
			case let .unsupportedMarker(marker):
				"Expected '∴' before the conclusion, found '\(marker)'"
			case let .tooManyStatements(limit, found):
				"Expected at most \(limit) statements, found \(found)"
		}
	}
}

/// A map written as one block of text, and read back.
///
/// - One statement per line. A final line marks the conclusion: `∴` in logic, and in English `∴`, `Therefore,`,
///   `Hence,` or `Thus,` (any case, comma optional). Blank lines are ignored.
/// - Logic splits like `LogicParser`: new lines and commas outside brackets, and the conclusion after `∴`, `⊢` or `⊨`.
///   English only splits on new lines, so commas inside a line are fine.
/// - Text is written in `order(of:kind:)`: premises first, then the conclusion if the map has one.
/// - The conclusion's English is written exactly as stored after `Therefore, `, so no case is changed.
///
/// A statement has to be one claim: logic holding a comma, new line or `∴` of its own, and a premise whose English starts
/// with `Therefore`, `Hence` or `Thus`, are read back as something else.
public enum ArgumentText {
	/// The statements in the order they're written, and the one that is the conclusion line
	public struct Order: Equatable, Sendable {
		/// The conclusion is last when there is one
		public var statements: [UUID]
		public var conclusion: UUID?
	}

	// MARK: - Writing

	/// Topological order, ties by position (top to bottom, then left to right). If the map has a final conclusion, the
	/// last one in that order moves to the end and becomes the conclusion line. Statements with no content of this
	/// kind are left out, and `apply` leaves them alone.
	public static func order(of map: ArgumentMap<some Any, some Any>, kind: ArgumentTextKind) -> Order {
		let byID = Dictionary(map.statements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		let ids = map.topologicalOrder().filter { id in
			byID[id].map { !ArgumentContent(of: $0, kind).isBlank } ?? false
		}

		guard let conclusion = ids.last(where: map.isFinalConclusion) else {
			return Order(statements: ids)
		}
		return Order(statements: ids.filter { $0 != conclusion } + [conclusion], conclusion: conclusion)
	}

	/// The logic of the map as editor entries, for the editor's own text view
	public static func entries(for map: ArgumentMap<some Any, some Any>) -> [LogicKeyboardEntry] {
		let order = order(of: map, kind: .logic)
		let byID = Dictionary(map.statements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

		var lines: [[LogicKeyboardEntry]] = []
		for id in order.statements {
			guard let statement = byID[id] else { continue }
			let logic = ArgumentContent.logic(statement.logic).normalized.logicEntries
			lines.append(id == order.conclusion ? [.symbol("∴")] + logic : logic)
		}

		return Array(lines.joined(separator: [.delimiter("\n")]))
	}

	public static func text(of map: ArgumentMap<some Any, some Any>, kind: ArgumentTextKind, letters: [String] = LogicLetters.defaults) -> String {
		switch kind {
			case .logic:
				return LogicInputVocabulary(letters: letters).text(for: entries(for: map))

			case .english:
				let order = order(of: map, kind: .english)
				let byID = Dictionary(map.statements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
				return order.statements.compactMap { id in
					byID[id].map { (id == order.conclusion ? "Therefore, " : "") + ArgumentContent.english($0.english).normalized.englishText }
				}.joined(separator: "\n")
		}
	}

	// MARK: - Reading

	struct Draft {
		var premises: [ArgumentContent] = []
		var conclusion: ArgumentContent?
	}

	static func draft(english text: String) throws(ArgumentTextProblem) -> Draft {
		var draft = Draft()

		for line in text.split(whereSeparator: \.isNewline) {
			let line = line.trimmingCharacters(in: .whitespaces)
			guard !line.isEmpty else { continue }

			guard let conclusion = conclusion(inEnglish: line) else {
				draft.premises.append(.english(line))
				continue
			}
			guard draft.conclusion == nil else { throw .multipleConclusions }
			guard !conclusion.isEmpty else { throw .missingConclusion }
			draft.conclusion = .english(conclusion)
		}

		return draft
	}

	/// What follows the conclusion marker, nil when the line doesn't start with one
	private static func conclusion(inEnglish line: String) -> String? {
		if line.hasPrefix("∴") {
			return String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
		}

		for word in ["therefore", "hence", "thus"] where line.prefix(word.count).lowercased() == word {
			let rest = line.dropFirst(word.count)
			guard rest.isEmpty || rest.first == "," || rest.first?.isWhitespace == true else { continue }
			let afterWord = rest.trimmingCharacters(in: .whitespaces)
			return afterWord.drop(while: { $0 == "," }).trimmingCharacters(in: .whitespaces)
		}

		return nil
	}

	/// Splits entries the way `LogicParser` does, but keeps statements that don't parse so a mistake doesn't delete a box
	static func draft(logic entries: [LogicKeyboardEntry]) throws(ArgumentTextProblem) -> Draft {
		var before: [[LogicKeyboardEntry]] = []
		var after: [[LogicKeyboardEntry]] = []
		var current: [LogicKeyboardEntry] = []
		var depth = 0
		var marked = false

		func close() {
			guard !current.isEmpty else { return }
			if marked {
				after.append(current)
			} else {
				before.append(current)
			}
			current = []
		}

		for entry in entries {
			switch entry {
				case .delimiter("("), .delimiter("["):
					depth += 1
					current.append(entry)

				case .delimiter(")"), .delimiter("]"):
					depth = max(depth - 1, 0)
					current.append(entry)

				case .delimiter(","):
					if depth == 0 {
						close()
					} else {
						current.append(entry)
					}

				case .delimiter("\n"), .symbol("∎"):
					depth = 0
					close()

				case .symbol("∴"), .symbol("⊢"), .symbol("⊨"):
					depth = 0
					close()
					guard !marked else { throw .multipleConclusions }
					marked = true

				case .symbol("∵"):
					throw .unsupportedMarker("∵")

				default:
					current.append(entry)
			}
		}
		close()

		if marked, after.isEmpty {
			throw .missingConclusion
		}
		guard after.count <= 1 else { throw .multipleConclusions }

		return Draft(premises: before.map(ArgumentContent.logic), conclusion: after.first.map(ArgumentContent.logic))
	}
}
