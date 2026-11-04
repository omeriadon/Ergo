//
//  OpenConceptIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenConceptIntent.swift

import AppIntents

struct OpenConceptIntent: OpenIntent {
	static var title: LocalizedStringResource = "Open Concept"

	static var description = IntentDescription(
		"Opens a specific concept in Ergo."
	)

	static var isDiscoverable: Bool {
		false
	}

	@Parameter(title: "Concept")
	var target: ConceptEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: .concepts,
			id: target.id
		)

		return .result()
	}
}
