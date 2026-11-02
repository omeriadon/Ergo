// Models for the seven bundled JSON catalogs.

import Foundation

nonisolated struct Example: Codable, Sendable {
	let text: String
	let note: String?

	private enum CodingKeys: String, CodingKey {
		case text
		case note
	}
}

nonisolated struct CatalogLink: Codable, Sendable {
	let target: CatalogReference
	let note: String

	private enum CodingKeys: String, CodingKey {
		case targetID
		case note
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let targetID = try container.decode(String.self, forKey: .targetID)
		target = try CatalogReference(id: targetID, from: decoder)
		note = try container.decode(String.self, forKey: .note)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(target.id, forKey: .targetID)
		try container.encode(note, forKey: .note)
	}
}

nonisolated enum BiasTag: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
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
}

nonisolated enum FallacyTag: String, Codable, CaseIterable, Hashable, Sendable {
	case causalReasoning = "causal-reasoning"
	case ethicsHistoryAndEconomics = "ethics-history-and-economics"
	case formalLogic = "formal-logic"
	case generalizationAndSampling = "generalization-and-sampling"
	case languageAndAmbiguity = "language-and-ambiguity"
	case premisesAndEvidence = "premises-and-evidence"
	case probabilityAndStatistics = "probability-and-statistics"
	case relevanceAndAppeals = "relevance-and-appeals"
	case relevanceAndDebate = "relevance-and-debate"
}

nonisolated enum RazorTag: String, Codable, CaseIterable, Hashable, Sendable {
	case attribution
	case decisionMaking = "decision-making"
	case evidence
	case interpretation
	case parsimony
}

nonisolated enum ConceptTag: String, Codable, CaseIterable, Hashable, Sendable {
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
}

nonisolated enum ParadoxTag: String, Codable, CaseIterable, Hashable, Sendable {
	case ethicsAndValue = "ethics-and-value"
	case knowledgeAndMeaning = "knowledge-and-meaning"
	case logicAndLanguage = "logic-and-language"
	case metaphysics
}

nonisolated enum CheckMode: String, Codable, Sendable {
	case solver
	case model
}

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

nonisolated struct ConceptEntry<Tag: Codable & Hashable & Sendable>: Codable, Identifiable, Sendable {
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
	let tags: [Tag]

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

typealias Concept = ConceptEntry<ConceptTag>
typealias Paradox = ConceptEntry<ParadoxTag>

nonisolated struct FallacyCatalog: Codable, Sendable {
	let fallacies: [Fallacy]

	private enum CodingKeys: String, CodingKey {
		case fallacies
	}
}

nonisolated struct RazorCatalog: Codable, Sendable {
	let razors: [Razor]

	private enum CodingKeys: String, CodingKey {
		case razors
	}
}

nonisolated struct BiasCatalog: Codable, Sendable {
	let biases: [Bias]

	private enum CodingKeys: String, CodingKey {
		case biases
	}
}

nonisolated struct LogicSymbolCatalog: Codable, Sendable {
	let symbols: [LogicSymbol]

	private enum CodingKeys: String, CodingKey {
		case symbols
	}
}

nonisolated struct ConceptCatalog: Codable, Sendable {
	let concepts: [Concept]

	private enum CodingKeys: String, CodingKey {
		case concepts
	}
}

nonisolated struct ParadoxCatalog: Codable, Sendable {
	let paradoxes: [Paradox]

	private enum CodingKeys: String, CodingKey {
		case paradoxes
	}
}

nonisolated struct Philosopher: Codable, Identifiable, Sendable {
	let id: String
	let name: String
	let image: String
	let birthYear: Int
	let deathYear: Int?
	let summary: String
	let related: [CatalogReference]

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case image
		case birthYear
		case deathYear
		case summary
		case related
	}
}

nonisolated struct PhilosopherCatalog: Codable, Sendable {
	let philosophers: [Philosopher]

	private enum CodingKeys: String, CodingKey {
		case philosophers
	}
}
