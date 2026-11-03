//
//  Argument.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import Defaults
import Foundation

nonisolated struct Argument: Codable, Identifiable, Sendable {
	let id: String
	let name: String
	let aliases: [String]
	let symbolName: String?
	let summary: String
	let body: String
	let origin: String?
	let keyFigures: [CatalogReference]
	let premises: [String]
	let conclusion: String
	let assumptions: [String]
	let objections: [ArgumentObjection]
	let examples: [Example]
	let related: [CatalogReference]
	let tags: [ArgumentTag]
}

nonisolated struct ArgumentCatalog: Codable, Sendable {
	let arguments: [Argument]
}

nonisolated struct ArgumentObjection: Codable, Sendable {
	let objection: String
	let reply: String
}

nonisolated enum ArgumentTag: String, Codable, Defaults.Serializable, CaseIterable, Identifiable, Hashable, Sendable {
	case ethics
	case epistemology
	case metaphysics
	case mind
	case religion
	case politicalPhilosophy = "political-philosophy"

	var title: String {
		switch self {
			case .politicalPhilosophy:
				"Political Philosophy"
			default:
				rawValue.capitalized
		}
	}

	var id: Self {
		self
	}
}
