//
//  BiasEntityQuery.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

struct BiasEntityQuery: EntityStringQuery {
	@Dependency
	private var catalog: CatalogStore

	func entities(for identifiers: [String]) async throws -> [BiasEntity] {
		try await catalog.load()

		let items = await catalog.biases.biases

		return items
			.filter { identifiers.contains($0.id) }
			.map(BiasEntity.init)
	}

	func entities(matching string: String) async throws -> [BiasEntity] {
		try await catalog.load()

		let items = await catalog.biases.biases

		return items
			.filter { item in
				item.name.localizedCaseInsensitiveContains(string)
					|| item.aliases.contains { $0.localizedCaseInsensitiveContains(string) }
			}
			.map(BiasEntity.init)
	}

	func suggestedEntities() async throws -> [BiasEntity] {
		try await catalog.load()

		let items = await catalog.biases.biases

		return items
			.prefix(20)
			.map(BiasEntity.init)
	}
}
