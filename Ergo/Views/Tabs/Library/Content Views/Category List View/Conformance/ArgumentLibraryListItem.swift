//
//  ArgumentLibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension Argument: LibraryListItem {
	nonisolated static let category: LibraryContent = .arguments
	nonisolated static let listTitle = "Arguments"
	nonisolated static let searchPrompt = "Search arguments"
	nonisolated static let countLabel = "arguments"
	nonisolated static let availableFilters = ArgumentTag.libraryFilters

	typealias Entity = ArgumentEntity

	nonisolated var filters: Set<LibraryFilter> {
		Set(tags.map(\.libraryFilter))
	}

	@MainActor
	var row: some View {
		Label(name, systemImage: symbolName ?? "text.bubble")
	}

	@MainActor
	static func all(in catalog: CatalogStore) -> [Argument] {
		catalog.arguments.arguments
	}

	nonisolated static func ranked(_ items: [Argument], query: String) async throws -> [Argument] {
		try await CatalogSearch.ranked(
			items,
			query: query,
			limit: CatalogSearch.resultLimit
		) { $0.searchFields }
	}
}
