//
//  ParadoxLibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension Paradox: LibraryListItem {
	nonisolated static let category: LibraryContent = .paradoxes
	nonisolated static let listTitle = "Paradoxes"
	nonisolated static let searchPrompt = "Search paradoxes"
	nonisolated static let countLabel = "paradoxes"
	nonisolated static let availableFilters = ParadoxTag.libraryFilters

	typealias Entity = ParadoxEntity

	nonisolated var filters: Set<LibraryFilter> {
		Set(tags.map(\.libraryFilter))
	}

	@MainActor
	var row: some View {
		Label(name, systemImage: "infinity")
	}

	@MainActor
	static func all(in catalog: CatalogStore) -> [Paradox] {
		catalog.paradoxes.paradoxes
	}

	nonisolated static func ranked(_ items: [Paradox], query: String) async throws -> [Paradox] {
		try await CatalogSearch.ranked(
			items,
			query: query,
			limit: CatalogSearch.resultLimit
		) { $0.searchFields }
	}
}
