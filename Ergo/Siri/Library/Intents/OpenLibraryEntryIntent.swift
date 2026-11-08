//
//  OpenLibraryEntryIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenLibraryEntryIntent.swift

import AppIntents

@AppIntent(.tool)
struct OpenLibraryEntryIntent: AppIntent {
	static let title: LocalizedStringResource = "Open Library Entry"

	static let description = IntentDescription(
		"Opens the page for one specific entry in Ergo's library. The entry can be a cognitive bias, a philosophical concept, a logical fallacy, a paradox, a razor, an argument, a philosopher, or a logic symbol."
	)

	@Parameter(
		title: "Entry",
		description: "The library entry to open, by name or alias. Any bias, concept, fallacy, paradox, razor, argument, philosopher, or logic symbol."
	)
	var target: LibraryEntry

	@Dependency
	private var navigation: NavigationManager

	static let supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: target.category,
			id: target.id
		)

		return .result()
	}
}
