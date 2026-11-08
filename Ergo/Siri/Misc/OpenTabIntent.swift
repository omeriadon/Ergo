//
//  OpenTabIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import Foundation

@AppIntent(.tool)
struct OpenTabIntent: AppIntent {
	static let title: LocalizedStringResource = "Open Tab"

	static let description = IntentDescription(
		"Opens a tab in Ergo."
	)

	@Parameter(title: "tab", description: "The tab to open in Ergo")
	var tab: AppTab

	static var parameterSummary: some ParameterSummary {
		Summary("Open the \(\.$tab) tab in Ergo.")
	}

	@Dependency
	private var navigation: NavigationManager

	static let supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.selectedTab = tab

		return .result()
	}
}
