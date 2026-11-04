//
//  LogicSymbolLibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension LogicSymbol: LibraryListItem {
	nonisolated static let category: LibraryContent = .symbols
	nonisolated static let listTitle = "Symbols"
	nonisolated static let searchPrompt = "Search logic symbols"
	nonisolated static let countLabel = "symbols"
	nonisolated static let showsSectionIndex = false
	nonisolated static let sortsByName = false
	nonisolated static let availableFilters = SymbolGroup.libraryFilters + SymbolTag.libraryFilters

	typealias Entity = SymbolEntity

	nonisolated var filters: Set<LibraryFilter> {
		Set([group.libraryFilter] + tags.map(\.libraryFilter))
	}

	nonisolated var sectionKey: LibrarySectionKey {
		LibrarySectionKey(
			order: SymbolGroup.allCases.firstIndex(of: group) ?? 0,
			title: group.rawValue.capitalized
		)
	}

	@MainActor
	var row: some View {
		HStack {
			Text(glyph)
				.font(.title)
				.fontDesign(.monospaced)
				.foregroundStyle(.accent)
				.frame(
					width: glyph.count < 3 ? 40 : 110,
					alignment: .leading
				)

			Text(name)
		}
	}

	@MainActor
	static func all(in catalog: CatalogStore) -> [LogicSymbol] {
		catalog.logicSymbols.symbols
	}

	nonisolated static func ranked(_ items: [LogicSymbol], query: String) async throws -> [LogicSymbol] {
		try await CatalogSearch.ranked(
			items,
			query: query,
			limit: CatalogSearch.resultLimit
		) { $0.searchFields }
	}
}
