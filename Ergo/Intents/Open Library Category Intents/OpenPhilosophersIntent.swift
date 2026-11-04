//
//  OpenPhilosophersIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenPhilosophersIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Philosophers"

	static var description = IntentDescription(
		"Opens the philosophers category in Ergo."
	)

	static var parameterSummary: some ParameterSummary {
		Summary("Open philosophers in Ergo")
	}

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.selectedTab = .library
		navigation.libraryPath.append(.category(.philosophers))

		return .result()
	}
}
