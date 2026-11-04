//
//  BiasLibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension Bias: LibraryListItem {
	nonisolated static let category: LibraryContent = .biases
	nonisolated static let listTitle = "Biases"
	nonisolated static let searchPrompt = "Search biases"
	nonisolated static let countLabel = "biases"
	nonisolated static let availableFilters = BiasTag.libraryFilters

	typealias Entity = BiasEntity

	nonisolated var filters: Set<LibraryFilter> {
		Set(tags.map(\.libraryFilter))
	}

	@MainActor
	var row: some View {
		Text(name)
	}

	@MainActor
	static func all(in catalog: CatalogStore) -> [Bias] {
		catalog.biases.biases
	}

	nonisolated static func ranked(_ items: [Bias], query: String) async throws -> [Bias] {
		try await CatalogSearch.ranked(
			items,
			query: query,
			limit: CatalogSearch.resultLimit
		) { $0.searchFields }
	}
}
