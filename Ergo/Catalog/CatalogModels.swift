// Models for the five bundled JSON catalogs.
// Catalog IDs and crosslinks are readable String slugs.
// Each built-in entry has exactly one category in tags.

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
    let targetID: String
    let note: String

    private enum CodingKeys: String, CodingKey {
        case targetID
        case note
    }
}

nonisolated enum CheckMode: String, Codable, Sendable {
    case solver
    case model
}

nonisolated enum SymbolGroup: String, Codable, Sendable {
    case connective
    case quantifier
    case modal
    case constant
    case relation
    case set
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
    let related: [String]
    let tags: [String]

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
    let related: [String]
    let tags: [String]

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
    let related: [String]
    let tags: [String]

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
    let related: [String]
    let tags: [String]

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

nonisolated struct Concept: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let aliases: [String]
    let symbolName: String?
    let summary: String
    let body: String
    let origin: String?
    let keyFigures: [String]
    let examples: [Example]
    let commonMisreadings: [String]
    let criticisms: [String]
    let lookalikes: [CatalogLink]
    let related: [String]
    let tags: [String]

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
