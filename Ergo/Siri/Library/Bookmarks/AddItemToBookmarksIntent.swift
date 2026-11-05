//
//  AddItemToBookmarksIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents
import Defaults

@AppIntent(.tool)
struct AddItemToBookmarksIntent: AppIntent {
	static let title: LocalizedStringResource = "Add Item To Bookmarks"

	@Parameter(title: "Item to Bookmark", description: "The item to bookmark in Ergo")
	var itemToBookmark: LibraryEntry

	static var supportedModes: IntentModes = [
		.background,
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		Defaults[.bookmarks].insert(CatalogReference(id: itemToBookmark.id, name: itemToBookmark.name, category: itemToBookmark.category))

		return .result()
	}
}
