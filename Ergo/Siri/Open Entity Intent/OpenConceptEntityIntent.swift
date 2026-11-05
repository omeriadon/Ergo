//
//  OpenConceptEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

/// What runs when a Concept link from Siri or Spotlight is tapped
struct OpenConceptEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Concept"

	@Parameter(title: "Concept")
	var target: ConceptEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .concepts, id: target.id)

		return .result()
	}
}
