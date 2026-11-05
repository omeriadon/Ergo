//
//  OpenArgumentEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

/// What runs when a Argument link from Siri or Spotlight is tapped
struct OpenArgumentEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Argument"

	@Parameter(title: "Argument")
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
