//
//  OpenLibraryCategoryIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import Foundation

struct OpenBookmarksIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Bookmarks"

	static var description = IntentDescription(
		"Opens bookmarks in Ergo."
	)

	static var parameterSummary: some ParameterSummary {
		Summary("Open bookmarks in Ergo.")
	}

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.selectedTab = .library
		navigation.libraryPath.append(.bookmarks)

		return .result()
	}
}
