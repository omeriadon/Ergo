//
//  Razor.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import Defaults

nonisolated struct Razor: Codable, Identifiable, Sendable {
	let id: String
	let name: String
	let aliases: [String]
	let symbolName: String?
	let summary: String
	let body: String
	let lensQuestion: String
	let examples: [Example]
	let limitations: [String]
	let related: [CatalogReference]
	let tags: [RazorTag]

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case aliases
		case symbolName
		case summary
		case body
		case lensQuestion
		case examples
		case limitations
		case related
		case tags
	}
}

nonisolated struct RazorCatalog: Codable, Sendable {
	let razors: [Razor]

	private enum CodingKeys: String, CodingKey {
		case razors
	}
}

nonisolated enum RazorTag: String, Codable, Defaults.Serializable, CaseIterable, Identifiable, Hashable, Sendable {
	case attribution
	case decisionMaking = "decision-making"
	case evidence
	case interpretation
	case parsimony

	var title: String {
		switch self {
			case .attribution:
				"Attribution"
			case .decisionMaking:
				"Decision Making"
			case .evidence:
				"Evidence"
			case .interpretation:
				"Interpretation"
			case .parsimony:
				"Parsimony"
		}
	}

	var id: Self {
		self
	}
}
