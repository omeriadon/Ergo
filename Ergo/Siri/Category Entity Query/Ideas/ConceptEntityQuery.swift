//
//  ConceptEntityQuery.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

struct ConceptEntityQuery: EntityStringQuery {
	@Dependency
	private var catalog: CatalogStore

	func entities(for identifiers: [String]) async throws -> [ConceptEntity] {
		try await catalog.load()

		let items = await catalog.concepts.concepts

		return items
			.filter { identifiers.contains($0.id) }
			.map(ConceptEntity.init)
	}

	func entities(matching string: String) async throws -> [ConceptEntity] {
		try await catalog.load()

		let items = await catalog.concepts.concepts

		return items
			.filter { item in
				item.name.localizedCaseInsensitiveContains(string)
					|| item.aliases.contains { $0.localizedCaseInsensitiveContains(string) }
			}
			.map(ConceptEntity.init)
	}

	func suggestedEntities() async throws -> [ConceptEntity] {
		try await catalog.load()

		let items = await catalog.concepts.concepts

		return items
			.prefix(20)
			.map(ConceptEntity.init)
	}
}
