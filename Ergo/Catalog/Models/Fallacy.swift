//
//  Fallacy.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import Defaults
import Foundation

nonisolated struct Fallacy: Codable, Identifiable, Sendable {
	let id: String
	let name: String
	let aliases: [String]
	let symbolName: String?
	let summary: String
	let body: String
	let detectionCriteria: String?
	let checkMode: CheckMode
	let examples: [Example]
	let doesNotCountWhen: [String]
	let lookalikes: [CatalogLink]
	let related: [CatalogReference]
	let tags: [FallacyTag]

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case aliases
		case symbolName
		case summary
		case body
		case detectionCriteria
		case checkMode
		case examples
		case doesNotCountWhen
		case lookalikes
		case related
		case tags
	}
}

nonisolated struct FallacyCatalog: Codable, Sendable {
	let fallacies: [Fallacy]

	private enum CodingKeys: String, CodingKey {
		case fallacies
	}
}

nonisolated enum FallacyTag: String, Codable, Defaults.Serializable, CaseIterable, Identifiable, Hashable, Sendable {
	case causalReasoning = "causal-reasoning"
	case ethicsHistoryAndEconomics = "ethics-history-and-economics"
	case formalLogic = "formal-logic"
	case generalizationAndSampling = "generalization-and-sampling"
	case languageAndAmbiguity = "language-and-ambiguity"
	case premisesAndEvidence = "premises-and-evidence"
	case probabilityAndStatistics = "probability-and-statistics"
	case relevanceAndAppeals = "relevance-and-appeals"
	case relevanceAndDebate = "relevance-and-debate"

	var title: String {
		rawValue.split(separator: "-").map { word in
			switch word {
				case "and":
					"&"
				case "of":
					"of"
				default:
					word.capitalized
			}
		}.joined(separator: " ")
	}

	var id: Self {
		self
	}
}

nonisolated enum CheckMode: String, Codable, Sendable {
	case solver
	case model
}
