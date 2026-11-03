//
//  Concept.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import Defaults
import Foundation

nonisolated struct Concept: Codable, Identifiable, Sendable {
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
	let tags: [ConceptTag]

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

nonisolated enum ConceptTag: String, Codable, Defaults.Serializable, CaseIterable, Identifiable, Hashable, Sendable {
	case aestheticsAndCulture = "aesthetics-and-culture"
	case decisionTheorySystemsAndMethods = "decision-theory-systems-and-methods"
	case epistemologyAndPhilosophyOfScience = "epistemology-and-philosophy-of-science"
	case ethicsAndValue = "ethics-and-value"
	case languageMeaningAndInterpretation = "language-meaning-and-interpretation"
	case logicAndReasoning = "logic-and-reasoning"
	case memoryLearningAndReportedPsychologicalEffects = "memory-learning-and-reported-psychological-effects"
	case metaphysicsAndOntology = "metaphysics-and-ontology"
	case mindConsciousnessAndAgency = "mind-consciousness-and-agency"
	case philosophicalSchoolsAndIsms = "philosophical-schools-and-isms"
	case politicalIdeologiesAndIsms = "political-ideologies-and-isms"
	case politicalPhilosophyAndInstitutions = "political-philosophy-and-institutions"
	case reasoningMethods = "reasoning-methods"
	case religionAsianAfricanAndIndigenousPhilosophy = "religion-asian-african-and-indigenous-philosophy"
	case thoughtExperiments = "thought-experiments"

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

nonisolated struct ConceptCatalog: Codable, Sendable {
	let concepts: [Concept]

	private enum CodingKeys: String, CodingKey {
		case concepts
	}
}
