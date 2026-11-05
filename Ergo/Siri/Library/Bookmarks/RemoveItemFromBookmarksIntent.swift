//
//  RemoveItemFromBookmarksIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents
import Defaults

@AppIntent(.tool)
struct RemoveItemFromBookmarksIntent: AppIntent {
	static let title: LocalizedStringResource = "Remove Item From Bookmarks"

	@Parameter(title: "Item to Remove from Bookmarks", description: "The item to remove from bookmarks in Ergo")
	var itemToRemoveFromBookmarks: LibraryEntry

	static var supportedModes: IntentModes = [
		.background, .foreground,
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		Defaults[.bookmarks].remove(CatalogReference(id: itemToRemoveFromBookmarks.id, name: itemToRemoveFromBookmarks.name, category: itemToRemoveFromBookmarks.category))

		return .result()
	}
}
