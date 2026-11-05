//
//  LogicEnglish.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation

/// Reads logic back as English. Exact over pretty: anything compound inside something else is bracketed,
/// so each sentence has only one reading. Letters with a descriptor read as the descriptor.
public enum LogicEnglish {
	/// One sentence per statement, with the conclusion last after "Therefore,"
	public static func text(for argument: LogicArgument, letters: [String], descriptors: [String]) -> String {
		let reader = Reader(letters: letters, descriptors: descriptors)
		var sentences = argument.premises.map { reader.sentence($0.formula) }

		if let conclusion = argument.conclusion {
			sentences.append("Therefore, " + reader.phrase(conclusion.formula, nested: false) + ".")
		}

		return sentences.joined(separator: "\n")
	}

	public static func text(for formula: LogicFormula, letters: [String], descriptors: [String]) -> String {
		Reader(letters: letters, descriptors: descriptors).sentence(formula)
	}
}

private struct Reader {
	let letters: [String]
	let descriptors: [String]

	func sentence(_ formula: LogicFormula) -> String {
		let phrase = phrase(formula, nested: false)
		guard let first = phrase.firstIndex(where: \.isLetter) else { return phrase + "." }
		return phrase.replacingCharacters(in: first ... first, with: phrase[first].uppercased()) + "."
	}

	/// `nested` brackets anything that isn't a single claim, since English has no precedence rules to lean on
	func phrase(_ formula: LogicFormula, nested: Bool) -> String {
		let text: String

		switch formula {
			case let .atom(slot):
				return claim(slot)
			case .truth:
				return "true"
			case let .predicate(slot, terms):
				return LogicLetters.letter(for: slot, in: letters) + "(" + terms.map { term($0, nested: false) }.joined(separator: ", ") + ")"
			case let .relation(relation, left, right):
				return term(left, nested: true) + " " + words(for: relation) + " " + term(right, nested: true)
			case let .not(value):
				text = "it is not the case that " + phrase(value, nested: true)
			case .and:
				text = list(formula.operands(of: .and), joinedBy: "and")
			case .or:
				text = list(formula.operands(of: .or), joinedBy: "or")
			case let .xor(left, right):
				text = "either " + phrase(left, nested: true) + " or " + phrase(right, nested: true) + ", but not both"
			case let .implies(left, right):
				text = "if " + phrase(left, nested: true) + ", then " + phrase(right, nested: true)
			case let .iff(left, right):
				text = phrase(left, nested: true) + " if and only if " + phrase(right, nested: true)
			case let .necessarily(value):
				text = "necessarily, " + phrase(value, nested: true)
			case let .possibly(value):
				text = "possibly, " + phrase(value, nested: true)
			case let .forAll(slot, body):
				text = "for every " + LogicLetters.letter(for: slot, in: letters) + ", " + phrase(body, nested: true)
			case let .exists(slot, body):
				text = "for some " + LogicLetters.letter(for: slot, in: letters) + ", " + phrase(body, nested: true)
		}

		return nested ? "(" + text + ")" : text
	}

	/// "X, Y and Z", which is exact because ∧ and ∨ don't care how they're grouped
	private func list(_ operands: [LogicFormula], joinedBy word: String) -> String {
		let parts = operands.map { phrase($0, nested: true) }
		return parts.dropLast().joined(separator: ", ") + " " + word + " " + parts[parts.count - 1]
	}

	private func claim(_ slot: Int) -> String {
		let descriptor = LogicLetters.descriptor(for: slot, in: descriptors)
		return descriptor.isEmpty ? LogicLetters.letter(for: slot, in: letters) : descriptor
	}

	private func term(_ term: LogicTerm, nested: Bool) -> String {
		let text: String

		switch term {
			case let .variable(slot):
				return LogicLetters.letter(for: slot, in: letters)
			case .emptySet:
				return "the empty set"
			case let .union(left, right):
				text = "the union of " + self.term(left, nested: true) + " and " + self.term(right, nested: true)
			case let .intersection(left, right):
				text = "the intersection of " + self.term(left, nested: true) + " and " + self.term(right, nested: true)
		}

		return nested ? "(" + text + ")" : text
	}

	private func words(for relation: LogicRelation) -> String {
		switch relation {
			case .equal: "equals"
			case .notEqual: "does not equal"
			case .member: "is a member of"
			case .notMember: "is not a member of"
			case .properSubset: "is a proper subset of"
			case .subset: "is a subset of"
		}
	}
}

private extension LogicFormula {
	enum Chain {
		case and, or
	}

	/// X∧(Y∧Z) and (X∧Y)∧Z both give [X, Y, Z]
	func operands(of chain: Chain) -> [LogicFormula] {
		switch (self, chain) {
			case let (.and(left, right), .and), let (.or(left, right), .or):
				left.operands(of: chain) + right.operands(of: chain)
			default:
				[self]
		}
	}
}
