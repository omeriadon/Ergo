//
//  OpenPhilosopherEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

/// What runs when a Philosopher link from Siri or Spotlight is tapped
struct OpenPhilosopherEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Philosopher"

	@Parameter(title: "Philosopher")
	var target: PhilosopherEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .philosophers, id: target.id)

		return .result()
	}
}
