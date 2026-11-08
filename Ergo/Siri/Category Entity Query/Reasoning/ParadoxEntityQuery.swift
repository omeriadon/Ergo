//
//  ParadoxEntityQuery.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

struct ParadoxEntityQuery: EntityStringQuery {
	@Dependency
	private var catalog: CatalogStore

	func entities(for identifiers: [String]) async throws -> [ParadoxEntity] {
		try await catalog.load()

		let items = await catalog.paradoxes.paradoxes

		return items
			.filter { identifiers.contains($0.id) }
			.map(ParadoxEntity.init)
	}

	func entities(matching string: String) async throws -> [ParadoxEntity] {
		try await catalog.load()

		let items = await catalog.paradoxes.paradoxes

		return items
			.filter { item in
				item.name.localizedCaseInsensitiveContains(string)
					|| item.aliases.contains { $0.localizedCaseInsensitiveContains(string) }
			}
			.map(ParadoxEntity.init)
	}

	func suggestedEntities() async throws -> [ParadoxEntity] {
		try await catalog.load()

		let items = await catalog.paradoxes.paradoxes

		return items
			.prefix(20)
			.map(ParadoxEntity.init)
	}
}
