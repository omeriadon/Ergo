//
//  SearchLibraryIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

@AppIntent(schema: .system.searchInApp)
struct SearchLibraryIntent: ShowInAppSearchResultsIntent {
	static var searchScopes: [StringSearchScope] = [.general]

	var criteria: StringSearchCriteria

	@Dependency
	private var navigation: NavigationManager

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.selectedTab = .library

		let term = criteria.term.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !term.isEmpty else {
			return .result()
		}

		if let route = navigation.libraryTagRoute(for: term) {
			navigation.libraryPath.append(route)
		} else if let category = navigation.currentLibraryCategory {
			navigation.librarySearchText[category] = term
		} else {
			navigation.libraryPath.removeAll()
			navigation.libraryGeneralSearchText = term
		}

		return .result()
	}
}
