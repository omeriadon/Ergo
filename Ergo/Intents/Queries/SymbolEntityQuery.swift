//
//  SymbolEntityQuery.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

struct SymbolEntityQuery: EntityStringQuery {
	@Dependency
	private var catalog: CatalogStore

	func entities(for identifiers: [String]) async throws -> [SymbolEntity] {
		try await catalog.load()

		let items = await catalog.logicSymbols.symbols

		return items
			.filter { identifiers.contains($0.id) }
			.map(SymbolEntity.init)
	}

	func entities(matching string: String) async throws -> [SymbolEntity] {
		try await catalog.load()

		let items = await catalog.logicSymbols.symbols

		return items
			.filter { item in
				item.name.localizedCaseInsensitiveContains(string)
					|| item.glyph == string
					|| item.alternateGlyphs.contains(string)
					|| item.aliases.contains { $0.localizedCaseInsensitiveContains(string) }
					|| item.shortcodes.contains { $0.localizedCaseInsensitiveContains(string) }
			}
			.map(SymbolEntity.init)
	}

	func suggestedEntities() async throws -> [SymbolEntity] {
		try await catalog.load()

		let items = await catalog.logicSymbols.symbols

		return items
			.prefix(20)
			.map(SymbolEntity.init)
	}
}
