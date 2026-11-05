//
//  OpenBiasEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

/// What runs when a Bias link from Siri or Spotlight is tapped
struct OpenBiasEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Bias"

	@Parameter(title: "Bias")
	var target: BiasEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .biases, id: target.id)

		return .result()
	}
}
