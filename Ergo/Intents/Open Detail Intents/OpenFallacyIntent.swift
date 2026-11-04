//
//  OpenFallacyIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenFallacyIntent.swift

import AppIntents

struct OpenFallacyIntent: OpenIntent {
	static var title: LocalizedStringResource = "Open Fallacy"

	static var description = IntentDescription(
		"Opens a specific fallacy in Ergo."
	)

	static var isDiscoverable: Bool {
		false
	}

	@Parameter(title: "Fallacy", description: "The target fallacy entity to open")
	var target: FallacyEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: .fallacies,
			id: target.id
		)

		return .result()
	}
}
