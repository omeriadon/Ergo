//
//  OpenParadoxEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenParadoxEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Paradox"

	@Parameter(title: "Paradox", description: "The paradox to open in Ergo")
	var target: ParadoxEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .paradoxes, id: target.id)

		return .result()
	}
}
