//
//  RazorLibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension Razor: LibraryListItem {
	nonisolated static let category: LibraryContent = .razors
	nonisolated static let listTitle = "Razors"
	nonisolated static let searchPrompt = "Search razors"
	nonisolated static let countLabel = "razors"
	nonisolated static let availableFilters = RazorTag.libraryFilters

	typealias Entity = RazorEntity

	nonisolated var filters: Set<LibraryFilter> {
		Set(tags.map(\.libraryFilter))
	}

	@MainActor
	var row: some View {
		Label(name, systemImage: "scissors")
	}

	@MainActor
	static func all(in catalog: CatalogStore) -> [Razor] {
		catalog.razors.razors
	}

	nonisolated static func ranked(_ items: [Razor], query: String) async throws -> [Razor] {
		try await CatalogSearch.ranked(
			items,
			query: query,
			limit: CatalogSearch.resultLimit
		) { $0.searchFields }
	}
}
