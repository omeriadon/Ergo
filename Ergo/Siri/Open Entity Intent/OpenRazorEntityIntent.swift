//
//  OpenRazorEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenRazorEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Razor"

	@Parameter(title: "Razor", description: "The razor to open in Ergo")
	var target: RazorEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .razors, id: target.id)

		return .result()
	}
}
