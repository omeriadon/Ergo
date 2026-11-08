//
//  OpenPhilosopherEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

/// Plain `OpenIntent` so Spotlight can open an indexed entity. Not a tool and hidden from Shortcuts: Siri and Shortcuts open entries through `OpenLibraryEntryIntent`.
struct OpenPhilosopherEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Philosopher"

	static let isDiscoverable = false

	@Parameter(title: "Philosopher", description: "The philosopher to open in Ergo")
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
