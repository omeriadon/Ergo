//
//  OpenBookmarksIntent 2.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenBookmarksIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Bookmarks"

	static let description = IntentDescription(
		"Opens the list of bookmarks in Ergo."
	)

	@Dependency
	private var navigation: NavigationManager

	static let supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.libraryPath.append(.bookmarks)

		return .result()
	}
}
