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
