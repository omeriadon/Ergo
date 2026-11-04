//
//  LibraryListItem.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import SwiftUI

nonisolated struct LibrarySectionKey: Hashable, Comparable, Sendable {
	let order: Int
	let title: String

	static func < (lhs: LibrarySectionKey, rhs: LibrarySectionKey) -> Bool {
		if lhs.order != rhs.order {
			return lhs.order < rhs.order
		}

		return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
	}
}

nonisolated protocol LibraryListItem: Identifiable, Sendable where ID == String {
	associatedtype Row: View
	associatedtype Entity: AppEntity where Entity.ID == String

	static var category: LibraryContent { get }
	static var listTitle: String { get }
	static var searchPrompt: String { get }
	static var countLabel: String { get }
	static var availableFilters: [LibraryFilter] { get }
	static var showsSectionIndex: Bool { get }
	static var sortsByName: Bool { get }

	var name: String { get }
	var filters: Set<LibraryFilter> { get }
	var sectionKey: LibrarySectionKey { get }

	@MainActor
	@ViewBuilder
	var row: Row { get }

	@MainActor
	static func all(in catalog: CatalogStore) -> [Self]

	static func ranked(_ items: [Self], query: String) async throws -> [Self]
}

extension LibraryListItem {
	nonisolated static var showsSectionIndex: Bool {
		true
	}

	nonisolated static var sortsByName: Bool {
		true
	}

	nonisolated var sectionKey: LibrarySectionKey {
		LibrarySectionKey(
			order: 0,
			title: String(name.prefix(1)).uppercased()
		)
	}
}

extension LibraryContent {
	var availableFilters: [LibraryFilter] {
		switch self {
			case .biases:
				Bias.availableFilters

			case .razors:
				Razor.availableFilters

			case .symbols:
				LogicSymbol.availableFilters

			case .concepts:
				Concept.availableFilters

			case .paradoxes:
				Paradox.availableFilters

			case .fallacies:
				Fallacy.availableFilters

			case .arguments:
				Argument.availableFilters

			case .philosophers:
				[]
		}
	}
}
