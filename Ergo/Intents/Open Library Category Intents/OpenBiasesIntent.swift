//
//  OpenBiasesIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import Foundation

struct OpenBiasesIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Biases"

	static var description = IntentDescription(
		"Opens the biases category in Ergo, optionally filtered by tag."
	)

	@Parameter(title: "Filter")
	var filter: BiasTag?

	static var parameterSummary: some ParameterSummary {
		Summary("Open biases in Ergo") {
			\.$filter
		}
	}

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.selectedTab = .library

		if let filter {
			navigation.libraryPath.append(.biases(filter: filter))
		} else {
			navigation.libraryPath.append(.category(.biases))
		}

		return .result()
	}
}
