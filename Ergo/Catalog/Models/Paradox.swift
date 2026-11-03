//
//  Paradox.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import Defaults

nonisolated struct Paradox: Codable, Identifiable, Sendable {
	let id: String
	let name: String
	let aliases: [String]
	let symbolName: String?
	let summary: String
	let body: String
	let origin: String?
	let keyFigures: [CatalogReference]
	let examples: [Example]
	let commonMisreadings: [String]
	let criticisms: [String]
	let lookalikes: [CatalogLink]
	let related: [CatalogReference]
	let tags: [ParadoxTag]

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case aliases
		case symbolName
		case summary
		case body
		case origin
		case keyFigures
		case examples
		case commonMisreadings
		case criticisms
		case lookalikes
		case related
		case tags
	}
}

nonisolated struct ParadoxCatalog: Codable, Sendable {
	let paradoxes: [Paradox]

	private enum CodingKeys: String, CodingKey {
		case paradoxes
	}
}

nonisolated enum ParadoxTag: String, Codable, Defaults.Serializable, CaseIterable, Identifiable, Hashable, Sendable {
	case ethicsAndValue = "ethics-and-value"
	case knowledgeAndMeaning = "knowledge-and-meaning"
	case logicAndLanguage = "logic-and-language"
	case metaphysics

	var title: String {
		switch self {
			case .ethicsAndValue:
				"Ethics & Value"
			case .knowledgeAndMeaning:
				"Knowledge & Meanings"
			case .logicAndLanguage:
				"Logic & Language"
			case .metaphysics:
				"Metaphysics"
		}
	}

	var id: Self {
		self
	}
}
