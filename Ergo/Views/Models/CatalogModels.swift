// Models for the five bundled JSON catalogs.
// Catalog IDs and crosslinks are readable String slugs.
// Each built-in entry has exactly one category in tags.

import Foundation

struct Example: Codable {
    let text: String
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case text
        case note
    }
}

struct CatalogLink: Codable {
    let targetID: String
    let note: String

    private enum CodingKeys: String, CodingKey {
        case targetID
        case note
    }
}

enum CheckMode: String, Codable {
    case solver
    case model
}

enum SymbolGroup: String, Codable {
    case connective
    case quantifier
    case modal
    case constant
    case relation
    case set
}

struct Fallacy: Codable, Identifiable {
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
    let contentVersion: Int

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
        case contentVersion
    }
}

struct Razor: Codable, Identifiable {
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
    let contentVersion: Int

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
        case contentVersion
    }
}

struct Bias: Codable, Identifiable {
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
    let contentVersion: Int

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
        case contentVersion
    }
}

struct LogicSymbol: Codable, Identifiable {
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
    let contentVersion: Int

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
        case contentVersion
    }
}

struct Concept: Codable, Identifiable {
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
    let contentVersion: Int

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
        case contentVersion
    }
}

struct FallacyCatalog: Codable {
    let schemaVersion: Int
    let fallacies: [Fallacy]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case fallacies
    }
}

struct RazorCatalog: Codable {
    let schemaVersion: Int
    let razors: [Razor]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case razors
    }
}

struct BiasCatalog: Codable {
    let schemaVersion: Int
    let biases: [Bias]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case biases
    }
}

struct LogicSymbolCatalog: Codable {
    let schemaVersion: Int
    let symbols: [LogicSymbol]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case symbols
    }
}

struct ConceptCatalog: Codable {
    let schemaVersion: Int
    let concepts: [Concept]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case concepts
    }
}
