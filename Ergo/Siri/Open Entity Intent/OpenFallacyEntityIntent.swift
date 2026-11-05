//
//  OpenFallacyEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenFallacyEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Fallacy"

	@Parameter(title: "Fallacy", description: "The fallacy to open in Ergo")
	var target: FallacyEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .fallacies, id: target.id)

		return .result()
	}
}
