//
//  OpenFallaciesIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenFallaciesIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Fallacies"

	static var description = IntentDescription(
		"Opens the fallacies category in Ergo, optionally filtered by tag."
	)

	@Parameter(title: "Filter")
	var filter: FallacyTag?

	static var parameterSummary: some ParameterSummary {
		Summary("Open fallacies in Ergo") {
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
			navigation.libraryPath.append(.fallacies(filter: filter))
		} else {
			navigation.libraryPath.append(.category(.fallacies))
		}

		return .result()
	}
}
