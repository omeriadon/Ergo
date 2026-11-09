//
//  PhilosopherLibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension Philosopher: LibraryListItem {
	nonisolated static let category: LibraryContent = .philosophers
	nonisolated static let listTitle = "Philosophers"
	nonisolated static let searchPrompt = "Search philosophers"
	nonisolated static let countLabel = "philosophers"
	nonisolated static let availableFilters: [LibraryFilter] = []

	typealias Entity = PhilosopherEntity

	nonisolated var filters: Set<LibraryFilter> {
		[]
	}

	@MainActor
	var row: some View {
		HStack {
			PhilosopherThumbnail(id: id)
				.frame(width: 40, height: 40)

			Text(name)
		}
	}

	nonisolated var sectionKey: LibrarySectionKey {
		let century = Int(floor(Double(birthYear - 1) / 100)) + 1
		return LibrarySectionKey(order: century, title: "\(century)")
	}

	@MainActor
	static func all(in catalog: CatalogStore) -> [Philosopher] {
		catalog.philosophers.philosophers
	}

	nonisolated static func ranked(_ items: [Philosopher], query: String) async throws -> [Philosopher] {
		try await CatalogSearch.ranked(
			items,
			query: query,
			limit: CatalogSearch.resultLimit
		) { $0.searchFields }
	}
}
