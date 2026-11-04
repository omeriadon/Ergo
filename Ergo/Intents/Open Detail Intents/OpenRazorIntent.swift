//
//  OpenRazorIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenRazorIntent.swift

import AppIntents

struct OpenRazorIntent: OpenIntent {
	static var title: LocalizedStringResource = "Open Razor"

	static var description = IntentDescription(
		"Opens a specific razor in Ergo."
	)

	static var isDiscoverable: Bool {
		false
	}

	@Parameter(title: "Razor", description: "The target razor entity to open")
	var target: RazorEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: .razors,
			id: target.id
		)

		return .result()
	}
}
