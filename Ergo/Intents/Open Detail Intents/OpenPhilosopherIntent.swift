//
//  OpenPhilosopherIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenPhilosopherIntent.swift

import AppIntents

struct OpenPhilosopherIntent: OpenIntent {
	static var title: LocalizedStringResource = "Open Philosopher"

	static var description = IntentDescription(
		"Opens a specific philosopher in Ergo."
	)

	static var isDiscoverable: Bool {
		false
	}

	@Parameter(title: "Philosopher")
	var target: PhilosopherEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: .philosophers,
			id: target.id
		)

		return .result()
	}
}
