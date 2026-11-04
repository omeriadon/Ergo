//
//  OpenBiasIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenBiasIntent.swift

import AppIntents

struct OpenBiasIntent: OpenIntent {
	static var title: LocalizedStringResource = "Open Bias"

	static var description = IntentDescription(
		"Opens a specific cognitive bias in Ergo."
	)

	static var isDiscoverable: Bool {
		false
	}

	@Parameter(title: "Bias")
	var target: BiasEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: .biases,
			id: target.id
		)

		return .result()
	}
}
