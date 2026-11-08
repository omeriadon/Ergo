//
//  RazorEntityQuery.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

struct RazorEntityQuery: EntityStringQuery {
	@Dependency
	private var catalog: CatalogStore

	func entities(for identifiers: [String]) async throws -> [RazorEntity] {
		try await catalog.load()

		let items = await catalog.razors.razors

		return items
			.filter { identifiers.contains($0.id) }
			.map(RazorEntity.init)
	}

	func entities(matching string: String) async throws -> [RazorEntity] {
		try await catalog.load()

		let items = await catalog.razors.razors

		return items
			.filter { item in
				item.name.localizedCaseInsensitiveContains(string)
					|| item.aliases.contains { $0.localizedCaseInsensitiveContains(string) }
			}
			.map(RazorEntity.init)
	}

	func suggestedEntities() async throws -> [RazorEntity] {
		try await catalog.load()

		let items = await catalog.razors.razors

		return items
			.prefix(20)
			.map(RazorEntity.init)
	}
}
