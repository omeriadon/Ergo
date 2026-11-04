//
//  SearchLibraryToolIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct SearchLibraryToolIntent: AppIntent {
	static let title: LocalizedStringResource = "Search Library"

	static let description = IntentDescription(
		"Searches the current list in Ergo for a word or phrase, such as a name or topic. If the phrase matches a category tag, filters the list to that tag instead."
	)

	@Parameter(
		title: "Search Text",
		description: "The word or phrase to search for, as plain text."
	)
	var query: String

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.applyLibrarySearch(term: query)

		return .result()
	}
}
