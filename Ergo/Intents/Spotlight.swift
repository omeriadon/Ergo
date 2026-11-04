//
//  Spotlight.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight
import Defaults

enum LibraryIndexer {
	/// Bump when entity properties or indexing keys change.
	static let schemaVersion = 2

	@MainActor
	static func indexIfNeeded(from catalog: CatalogStore) async throws {
		let build = Bundle.main.object(
			forInfoDictionaryKey: "CFBundleVersion"
		) as? String ?? "0"

		let current = "\(build).\(schemaVersion)"

		guard Defaults[.lastIndexedVersion] != current else {
			return
		}

		try await catalog.load()

		let index = CSSearchableIndex.default()

		try await index.deleteAllSearchableItems()

		try await index.indexAppEntities(catalog.biases.biases.map(BiasEntity.init))
		try await index.indexAppEntities(catalog.concepts.concepts.map(ConceptEntity.init))
		try await index.indexAppEntities(catalog.fallacies.fallacies.map(FallacyEntity.init))
		try await index.indexAppEntities(catalog.razors.razors.map(RazorEntity.init))
		try await index.indexAppEntities(catalog.logicSymbols.symbols.map(SymbolEntity.init))
		try await index.indexAppEntities(catalog.paradoxes.paradoxes.map(ParadoxEntity.init))
		try await index.indexAppEntities(catalog.philosophers.philosophers.map(PhilosopherEntity.init))
		try await index.indexAppEntities(catalog.arguments.arguments.map(ArgumentEntity.init))

		Defaults[.lastIndexedVersion] = current
	}
}
