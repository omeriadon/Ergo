//
//  OpenParadoxesIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenParadoxesIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Paradoxes"

	static var description = IntentDescription(
		"Opens the paradoxes category in Ergo, optionally filtered by tag."
	)

	@Parameter(title: "Filter")
	var filter: ParadoxTag?

	static var parameterSummary: some ParameterSummary {
		Summary("Open paradoxes in Ergo") {
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
			navigation.libraryPath.append(.paradoxes(filter: filter))
		} else {
			navigation.libraryPath.append(.category(.paradoxes))
		}

		return .result()
	}
}
