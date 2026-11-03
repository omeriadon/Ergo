//
//  Philosopher.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

nonisolated struct Philosopher: Codable, Identifiable, Sendable {
	let id: String
	let name: String
	let image: String
	let birthYear: Int
	let deathYear: Int?
	let summary: String
	let body: String
	let related: [CatalogReference]

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case image
		case birthYear
		case deathYear
		case summary
		case body
		case related
	}
}

nonisolated struct PhilosopherCatalog: Codable, Sendable {
	let philosophers: [Philosopher]

	private enum CodingKeys: String, CodingKey {
		case philosophers
	}
}
