//
//  FallacyLibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension Fallacy: LibraryListItem {
	nonisolated static let category: LibraryContent = .fallacies
	nonisolated static let listTitle = "Fallacies"
	nonisolated static let searchPrompt = "Search fallacies"
	nonisolated static let countLabel = "fallacies"
	nonisolated static let availableFilters = FallacyTag.libraryFilters

	typealias Entity = FallacyEntity

	nonisolated var filters: Set<LibraryFilter> {
		Set(tags.map(\.libraryFilter))
	}

	@MainActor
	var row: some View {
		Label(name, systemImage: symbolName ?? "repeat.badge.xmark")
	}

	@MainActor
	static func all(in catalog: CatalogStore) -> [Fallacy] {
		catalog.fallacies.fallacies
	}

	nonisolated static func ranked(_ items: [Fallacy], query: String) async throws -> [Fallacy] {
		try await CatalogSearch.ranked(
			items,
			query: query,
			limit: CatalogSearch.resultLimit
		) { $0.searchFields }
	}
}
