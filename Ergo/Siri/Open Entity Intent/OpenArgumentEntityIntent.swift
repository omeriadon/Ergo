//
//  OpenArgumentEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

/// Plain `OpenIntent` so Spotlight can open an indexed entity. Not a tool and hidden from Shortcuts: Siri and Shortcuts open entries through `OpenLibraryEntryIntent`.
struct OpenArgumentEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Argument"

	static let isDiscoverable = false

	@Parameter(title: "Argument", description: "The argument to open in Ergo")
	var target: ArgumentEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .arguments, id: target.id)

		return .result()
	}
}
