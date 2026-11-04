//
//  OpenConceptsIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenConceptsIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Concepts"

	static var description = IntentDescription(
		"Opens the concepts category in Ergo, optionally filtered by tag."
	)

	@Parameter(title: "Filter")
	var filter: ConceptTag?

	static var parameterSummary: some ParameterSummary {
		Summary("Open concepts in Ergo") {
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
			navigation.libraryPath.append(.concepts(filter: filter))
		} else {
			navigation.libraryPath.append(.category(.concepts))
		}

		return .result()
	}
}
