//
//  PhilosopherEntityQuery.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

struct PhilosopherEntityQuery: EntityStringQuery {
	@Dependency
	private var catalog: CatalogStore

	func entities(for identifiers: [String]) async throws -> [PhilosopherEntity] {
		try await catalog.load()

		let items = await catalog.philosophers.philosophers

		return items
			.filter { identifiers.contains($0.id) }
			.map(PhilosopherEntity.init)
	}

	func entities(matching string: String) async throws -> [PhilosopherEntity] {
		try await catalog.load()

		let items = await catalog.philosophers.philosophers

		return items
			.filter { $0.name.localizedCaseInsensitiveContains(string) }
			.map(PhilosopherEntity.init)
	}

	func suggestedEntities() async throws -> [PhilosopherEntity] {
		try await catalog.load()

		let items = await catalog.philosophers.philosophers

		return items
			.prefix(20)
			.map(PhilosopherEntity.init)
	}
}
