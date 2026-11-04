//
//  Symbol.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import AppIntents
import Defaults
import Foundation

nonisolated enum SymbolGroup: String, Codable, CaseIterable, Identifiable, Sendable, AppEnum {
	case connective
	case quantifier
	case modal
	case constant
	case relation
	case set

	var id: Self {
		self
	}

	static var typeDisplayRepresentation: TypeDisplayRepresentation {
		TypeDisplayRepresentation(name: "Symbol Group")
	}

	static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.connective: DisplayRepresentation(title: "Connective"),
		.quantifier: DisplayRepresentation(title: "Quantifier"),
		.modal: DisplayRepresentation(title: "Modal"),
		.constant: DisplayRepresentation(title: "Constant"),
		.relation: DisplayRepresentation(title: "Relation"),
		.set: DisplayRepresentation(title: "Set"),
	]
}

nonisolated struct LogicSymbolCatalog: Codable, Sendable {
	let symbols: [LogicSymbol]

	private enum CodingKeys: String, CodingKey {
		case symbols
	}
}

nonisolated struct LogicSymbol: Codable, Identifiable, Sendable {
	let id: String
	let name: String
	let glyph: String
	let alternateGlyphs: [String]
	let aliases: [String]
	let group: SymbolGroup
	let arity: Int
	let shortcodes: [String]
	let englishReadings: [String]
	let summary: String
	let body: String
	let examples: [Example]
	let limitations: [String]
	let lookalikes: [CatalogLink]
	let related: [CatalogReference]
	let tags: [SymbolTag]

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case glyph
		case alternateGlyphs
		case aliases
		case group
		case arity
		case shortcodes
		case englishReadings
		case summary
		case body
		case examples
		case limitations
		case lookalikes
		case related
		case tags
	}
}

enum SymbolTag: String, Codable, Hashable, Identifiable, CaseIterable, Sendable, AppEnum {
	case modalLogic = "modal-logic"
	case predicateLogic = "predicate-logic"
	case proofNotation = "proof-notation"
	case propositionalLogic = "propositional-logic"
	case setNotation = "set-notation"

	var desciption: String {
		switch self {
			case .modalLogic:
				"Modal logic"
			case .predicateLogic:
				"Predicate logic"
			case .proofNotation:
				"Proof notation"
			case .propositionalLogic:
				"Propositional logic"
			case .setNotation:
				"Set notation"
		}
	}

	var title: String {
		desciption
	}

	var id: Self {
		self
	}

	static var typeDisplayRepresentation: TypeDisplayRepresentation {
		TypeDisplayRepresentation(name: "Symbol Tag")
	}

	static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.modalLogic: DisplayRepresentation(title: "Modal logic"),
		.predicateLogic: DisplayRepresentation(title: "Predicate logic"),
		.proofNotation: DisplayRepresentation(title: "Proof notation"),
		.propositionalLogic: DisplayRepresentation(title: "Propositional logic"),
		.setNotation: DisplayRepresentation(title: "Set notation"),
	]
}

enum SymbolSearchToken: Hashable, Identifiable, Codable, Defaults.Serializable {
	case group(SymbolGroup)
	case tag(SymbolTag)

	var id: Self {
		self
	}

	var title: String {
		switch self {
			case let .group(group):
				group.rawValue.capitalized

			case let .tag(tag):
				tag.title
		}
	}

	var symbol: String {
		switch self {
			case .group:
				"sum"

			case .tag:
				"tag"
		}
	}

	var kindTitle: String {
		switch self {
			case .group:
				"Group"

			case .tag:
				"Tag"
		}
	}
}

enum SymbolEnum: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
	case accessibilityRelation
	case alwaysOperator
	case becauseMarker
	case beliefOperator
	case boundedExistentialQuantifier
	case boundedUniversalQuantifier
	case conjunction
	case definiteDescription
	case definitionMarker
	case emptySet
	case endOfProofMarker
	case eventuallyOperator
	case exclusiveDisjunction
	case existentialQuantifier
	case failureOfEntailment
	case falsityConstant
	case formalDerivability
	case formalNonderivability
	case formulaMetavariable
	case functionApplication
	case groupingDelimiters
	case hilbertChoiceOperator
	case identity
	case disjunction
	case individualConstant
	case individualVariable
	case interpretationBrackets
	case knowledgeOperator
	case lambdaAbstraction
	case logicalEquivalenceMarker
	case logicalValidityMarker
	case materialBiconditional
	case materialConditional
	case modelSatisfaction
	case nand
	case necessityOperator
	case negatedExistentialQuantifier
	case negation
	case nextOperator
	case nonidentity
	case nor
	case obligationOperator
	case permissionOperator
	case possibilityOperator
	case predicateApplication
	case predicateLetter
	case premiseSetMetavariable
	case prohibitionOperator
	case properSubset
	case relationApplication
	case semanticConsequence
	case sentenceLetter
	case sequentArrow
	case setIntersection
	case setMembership
	case setNonmembership
	case setUnion
	case subset
	case substitutionNotation
	case theoremhoodMarker
	case thereforeMarker
	case truthConstant
	case typeAnnotation
	case uniqueExistentialQuantifier
	case universalQuantifier
	case untilOperator

	var id: SymbolEnum {
		self
	}

	var glyph: String {
		switch self {
			case .accessibilityRelation: "R"
			case .alwaysOperator: "G"
			case .becauseMarker: "∵"
			case .beliefOperator: "Bₐ"
			case .boundedExistentialQuantifier: "∃x ∈ A"
			case .boundedUniversalQuantifier: "∀x ∈ A"
			case .conjunction: "∧"
			case .definiteDescription: "ι"
			case .definitionMarker: "≔"
			case .emptySet: "∅"
			case .endOfProofMarker: "∎"
			case .eventuallyOperator: "F"
			case .exclusiveDisjunction: "⊕"
			case .existentialQuantifier: "∃"
			case .failureOfEntailment: "⊭"
			case .falsityConstant: "⊥"
			case .formalDerivability: "⊢"
			case .formalNonderivability: "⊬"
			case .formulaMetavariable: "φ"
			case .functionApplication: "f(·)"
			case .groupingDelimiters: "( )"
			case .hilbertChoiceOperator: "ε"
			case .identity: "="
			case .disjunction: "∨"
			case .individualConstant: "a"
			case .individualVariable: "x"
			case .interpretationBrackets: "⟦ ⟧"
			case .knowledgeOperator: "Kₐ"
			case .lambdaAbstraction: "λ"
			case .logicalEquivalenceMarker: "⇔"
			case .logicalValidityMarker: "⊨"
			case .materialBiconditional: "↔"
			case .materialConditional: "→"
			case .modelSatisfaction: "⊨"
			case .nand: "↑"
			case .necessityOperator: "□"
			case .negatedExistentialQuantifier: "∄"
			case .negation: "¬"
			case .nextOperator: "X"
			case .nonidentity: "≠"
			case .nor: "↓"
			case .obligationOperator: "O"
			case .permissionOperator: "P"
			case .possibilityOperator: "◇"
			case .predicateApplication: "P(·)"
			case .predicateLetter: "P"
			case .premiseSetMetavariable: "Γ"
			case .prohibitionOperator: "F"
			case .properSubset: "⊊"
			case .relationApplication: "R(·,·)"
			case .semanticConsequence: "⊨"
			case .sentenceLetter: "p"
			case .sequentArrow: "⇒"
			case .setIntersection: "∩"
			case .setMembership: "∈"
			case .setNonmembership: "∉"
			case .setUnion: "∪"
			case .subset: "⊆"
			case .substitutionNotation: "[t/x]"
			case .theoremhoodMarker: "⊢"
			case .thereforeMarker: "∴"
			case .truthConstant: "⊤"
			case .typeAnnotation: ":"
			case .uniqueExistentialQuantifier: "∃!"
			case .universalQuantifier: "∀"
			case .untilOperator: "U"
		}
	}

	static let basic: [SymbolEnum] = [
		.negation,
		.conjunction,
		.disjunction,
		.materialConditional,
		.materialBiconditional,
	]

	static let predicate: [SymbolEnum] = [
		.universalQuantifier,
		.existentialQuantifier,
		.uniqueExistentialQuantifier,

		.identity,
		.nonidentity,
		.individualVariable,
		.individualConstant,
		.predicateLetter,
		.predicateApplication,
		.relationApplication,
		.functionApplication,
	]

	var name: String {
		switch self {
			case .nand: "NAND"
			case .nor: "NOR"
			case .disjunction: "Inclusive disjunction"
			default:
				rawValue
					.replacingOccurrences(
						of: "([a-z])([A-Z])",
						with: "$1 $2",
						options: .regularExpression
					)
					.capitalized
		}
	}
}
