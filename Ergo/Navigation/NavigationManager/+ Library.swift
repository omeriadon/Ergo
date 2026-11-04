//
//  + Library.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension NavigationManager {
	// MARK: - currentLibraryCategory

	var currentLibraryCategory: LibraryContent? {
		switch libraryPath.last {
			case let .category(category), let .detail(category, _):
				category

			case .symbols:
				.symbols

			case .biases:
				.biases

			case .razors:
				.razors

			case .paradoxes:
				.paradoxes

			case .concepts:
				.concepts

			case .fallacies:
				.fallacies

			case .arguments:
				.arguments

			case .bookmarks, nil:
				nil
		}
	}

	// MARK: - listState

	func listState(for category: LibraryContent) -> LibraryListState {
		listStates[category] ?? LibraryListState()
	}

	// MARK: - showLibraryList

	func showLibraryList(
		_ category: LibraryContent,
		filters: [LibraryFilter]? = nil
	) {
		selectedTab = .library

		if let index = libraryPath.lastIndex(where: { $0.listCategory == category }) {
			libraryPath.removeSubrange((index + 1)...)
		} else {
			libraryPath.append(.category(category))
		}

		if let filters {
			listState(for: category).filters = filters
		}
	}

	// MARK: - applyLibrarySearch

	func applyLibrarySearch(term: String) {
		selectedTab = .library

		let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !trimmed.isEmpty else {
			return
		}

		if let match = filterMatch(for: trimmed) {
			showLibraryList(match.category)
			listState(for: match.category).add(match.filter)
		} else if let category = currentLibraryCategory {
			listState(for: category).searchText = trimmed
		} else {
			libraryPath.removeAll()
			libraryGeneralSearchText = trimmed
		}
	}

	// MARK: - filterMatch

	private func filterMatch(
		for term: String
	) -> (category: LibraryContent, filter: LibraryFilter)? {
		let current = currentLibraryCategory

		let ordered = LibraryContent.allCases.filter { $0 == current }
			+ LibraryContent.allCases.filter { $0 != current }

		for category in ordered {
			if let filter = category.availableFilters.first(where: { $0.matches(term: term) }) {
				return (category, filter)
			}
		}

		return nil
	}
}
