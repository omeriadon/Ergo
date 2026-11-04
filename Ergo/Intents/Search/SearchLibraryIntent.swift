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
		navigation.applyLibrarySearch(term: criteria.term)

		return .result()
	}
}
