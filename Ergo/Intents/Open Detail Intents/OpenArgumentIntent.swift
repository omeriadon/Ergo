//
//  OpenArgumentIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenArgumentIntent.swift

import AppIntents

struct OpenArgumentIntent: OpenIntent {
	static var title: LocalizedStringResource = "Open Argument"

	static var description = IntentDescription(
		"Opens a specific argument in Ergo."
	)

	static var isDiscoverable: Bool {
		false
	}

	@Parameter(title: "Argument")
	var target: ArgumentEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: .arguments,
			id: target.id
		)

		return .result()
	}
}
