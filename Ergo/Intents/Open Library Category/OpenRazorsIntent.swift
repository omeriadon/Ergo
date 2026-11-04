//
//  OpenRazorsIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

struct OpenRazorsIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Razors"

	static var description = IntentDescription(
		"Opens the razors category in Ergo, optionally filtered by tag."
	)

	@Parameter(title: "Filter")
	var filter: RazorTag?

	static var parameterSummary: some ParameterSummary {
		Summary("Open razors in Ergo") {
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
			navigation.libraryPath.append(.razors(filter: filter))
		} else {
			navigation.libraryPath.append(.category(.razors))
		}

		return .result()
	}
}
