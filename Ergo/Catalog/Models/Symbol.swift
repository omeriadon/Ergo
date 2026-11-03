//
//  Symbol.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import Defaults
import Foundation

nonisolated enum SymbolGroup: String, Codable, CaseIterable, Identifiable, Sendable {
	case connective
	case quantifier
	case modal
	case constant
	case relation
	case set

	var id: Self {
		self
	}
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

enum SymbolTag: String, Codable, Hashable, Identifiable, CaseIterable, Sendable {
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
}
