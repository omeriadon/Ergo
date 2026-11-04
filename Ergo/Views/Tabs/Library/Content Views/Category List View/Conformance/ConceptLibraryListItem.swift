//
//  ConceptLibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension Concept: LibraryListItem {
	nonisolated static let category: LibraryContent = .concepts
	nonisolated static let listTitle = "Concepts"
	nonisolated static let searchPrompt = "Search concepts"
	nonisolated static let countLabel = "concepts"
	nonisolated static let availableFilters = ConceptTag.libraryFilters

	typealias Entity = ConceptEntity

	nonisolated var filters: Set<LibraryFilter> {
		Set(tags.map(\.libraryFilter))
	}

	@MainActor
	var row: some View {
		Label(name, systemImage: symbolName ?? "book.closed")
	}

	@MainActor
	static func all(in catalog: CatalogStore) -> [Concept] {
		catalog.concepts.concepts
	}

	nonisolated static func ranked(_ items: [Concept], query: String) async throws -> [Concept] {
		try await CatalogSearch.ranked(
			items,
			query: query,
			limit: CatalogSearch.resultLimit
		) { $0.searchFields }
	}
}
