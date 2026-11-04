//
//  FallacyEntityQuery.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

struct FallacyEntityQuery: EntityStringQuery {
	@Dependency
	private var catalog: CatalogStore

	func entities(for identifiers: [String]) async throws -> [FallacyEntity] {
		try await catalog.load()

		let items = await catalog.fallacies.fallacies

		return items
			.filter { identifiers.contains($0.id) }
			.map(FallacyEntity.init)
	}

	func entities(matching string: String) async throws -> [FallacyEntity] {
		try await catalog.load()

		let items = await catalog.fallacies.fallacies

		return items
			.filter { item in
				item.name.localizedCaseInsensitiveContains(string)
					|| item.aliases.contains { $0.localizedCaseInsensitiveContains(string) }
			}
			.map(FallacyEntity.init)
	}

	func suggestedEntities() async throws -> [FallacyEntity] {
		try await catalog.load()

		let items = await catalog.fallacies.fallacies

		return items
			.prefix(20)
			.map(FallacyEntity.init)
	}
}
