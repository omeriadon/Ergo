//
//  LibraryListLogic.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import Foundation

nonisolated struct LibrarySection<Item: LibraryListItem>: Identifiable {
	let title: String
	let items: [Item]

	var id: String {
		title
	}
}

nonisolated enum LibraryListLogic {
	static func visibleItems<Item: LibraryListItem>(
		all: [Item],
		searched: [Item],
		isSearching: Bool,
		filters: [LibraryFilter]
	) -> [Item] {
		let source = isSearching ? searched : all
		let filtered = source.filter { matches($0, filters: filters) }

		guard isSearching else {
			return filtered
		}

		return Array(filtered.prefix(CatalogSearch.resultLimit))
	}

	static func matches(
		_ item: some LibraryListItem,
		filters: [LibraryFilter]
	) -> Bool {
		let selectedByKind = Dictionary(grouping: filters, by: \.kind)

		return selectedByKind.values.allSatisfy { selected in
			!Set(selected).isDisjoint(with: item.filters)
		}
	}

	static func sections<Item: LibraryListItem>(
		_ items: [Item]
	) -> [LibrarySection<Item>] {
		let grouped = Dictionary(grouping: items, by: \.sectionKey)

		return grouped.keys.sorted().map { key in
			let members = grouped[key] ?? []

			let ordered = Item.sortsByName
				? members.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
				: members

			return LibrarySection(title: key.title, items: ordered)
		}
	}

	static func suggestions(
		available: [LibraryFilter],
		selected: [LibraryFilter],
		term: String
	) -> [LibraryFilter] {
		available.filter { filter in
			!selected.contains(filter)
				&& (term.isEmpty || filter.title.localizedStandardContains(term))
		}
	}
}
