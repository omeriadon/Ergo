//
//  OpenParadoxIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenParadoxIntent.swift

import AppIntents

struct OpenParadoxIntent: OpenIntent {
	static var title: LocalizedStringResource = "Open Paradox"

	static var description = IntentDescription(
		"Opens a specific paradox in Ergo."
	)

	static var isDiscoverable: Bool {
		false
	}

	@Parameter(title: "Paradox", description: "The target paradox entity to open")
	var target: ParadoxEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: .paradoxes,
			id: target.id
		)

		return .result()
	}
}
