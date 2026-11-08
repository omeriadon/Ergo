//
//  Bias.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import AppIntents
import Defaults

nonisolated struct Bias: Codable, Identifiable, Sendable {
	let id: String
	let name: String
	let aliases: [String]
	let symbolName: String?
	let summary: String
	let body: String
	let examples: [Example]
	let counters: [String]
	let limitations: [String]
	let evidenceNote: String?
	let lookalikes: [CatalogLink]
	let related: [CatalogReference]
	let tags: [BiasTag]

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case aliases
		case symbolName
		case summary
		case body
		case examples
		case counters
		case limitations
		case evidenceNote
		case lookalikes
		case related
		case tags
	}
}

nonisolated struct BiasCatalog: Codable, Sendable {
	let biases: [Bias]

	private enum CodingKeys: String, CodingKey {
		case biases
	}
}

nonisolated enum BiasTag: String, Codable, Defaults.Serializable, CaseIterable, Identifiable, Hashable, Sendable, AppEnum {
	case attention
	case attribution
	case beliefAssessment = "belief-assessment"
	case decisionMaking = "decision-making"
	case memory
	case researchAndMeasurement = "research-and-measurement"
	case socialJudgment = "social-judgment"

	var title: String {
		switch self {
			case .attention:
				"Attention"
			case .attribution:
				"Attribution"
			case .beliefAssessment:
				"Belief Assessment"
			case .decisionMaking:
				"Decision Making"
			case .memory:
				"Memory"
			case .researchAndMeasurement:
				"Research & Measurement"
			case .socialJudgment:
				"Social Judgement"
		}
	}

	var id: Self {
		self
	}

	static var typeDisplayRepresentation: TypeDisplayRepresentation {
		TypeDisplayRepresentation(name: "Bias Tag")
	}

	static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.attention: DisplayRepresentation(title: "Attention"),
		.attribution: DisplayRepresentation(title: "Attribution"),
		.beliefAssessment: DisplayRepresentation(title: "Belief Assessment"),
		.decisionMaking: DisplayRepresentation(title: "Decision Making"),
		.memory: DisplayRepresentation(title: "Memory"),
		.researchAndMeasurement: DisplayRepresentation(title: "Research & Measurement"),
		.socialJudgment: DisplayRepresentation(title: "Social Judgement"),
	]
}
