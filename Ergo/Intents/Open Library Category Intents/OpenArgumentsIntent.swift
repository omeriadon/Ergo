//
//  OpenArgumentsIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenArgumentsIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Arguments"

	static var description = IntentDescription(
		"Opens the arguments category in Ergo, optionally filtered by tag."
	)

	@Parameter(title: "Filter")
	var filter: ArgumentTag?

	static var parameterSummary: some ParameterSummary {
		Summary("Open arguments in Ergo") {
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
			navigation.libraryPath.append(.arguments(filter: filter))
		} else {
			navigation.libraryPath.append(.category(.arguments))
		}

		return .result()
	}
}
