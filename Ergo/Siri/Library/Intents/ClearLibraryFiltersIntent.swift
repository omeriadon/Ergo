//
//  ClearLibraryFiltersIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct ClearLibraryFiltersIntent: AppIntent {
	static let title: LocalizedStringResource = "Clear Filters"

	static let description = IntentDescription(
		"Removes all tag and group filters from the library list currently shown in Ergo."
	)

	@Dependency
	private var navigation: NavigationManager

	static let supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		if let category = navigation.currentLibraryCategory {
			navigation.listState(for: category).clearFilters()
		}

		return .result()
	}
}
