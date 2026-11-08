//
//  SetBookmarkIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import AppIntents
import Defaults

/// What `SetBookmarkIntent` does to the entry's bookmark. An `AppEnum` so each case carries a description Siri's model can read.
enum BookmarkAction: String, AppEnum {
	case add
	case remove

	static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bookmark Action")

	static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.add: DisplayRepresentation(title: "Add", subtitle: "Bookmarks the entry. Does nothing if it is already bookmarked."),
		.remove: DisplayRepresentation(title: "Remove", subtitle: "Removes the entry's bookmark. Does nothing if it isn't bookmarked."),
	]
}

@AppIntent(.tool)
struct SetBookmarkIntent: AppIntent {
	static let title: LocalizedStringResource = "Add or Remove Bookmark"

	static let description = IntentDescription(
		"Adds or removes the bookmark on one entry in Ergo's library: a cognitive bias, a philosophical concept, a logical fallacy, a paradox, a razor, an argument, a philosopher, or a logic symbol. Use it when someone asks to bookmark, save or favorite an entry, or to unbookmark one. It only changes the bookmarks list and doesn't open anything.",
		searchKeywords: ["save", "favorite", "unbookmark"]
	)

	@Parameter(
		title: "Entry",
		description: "The library entry to bookmark or unbookmark, by name or alias. Any bias, concept, fallacy, paradox, razor, argument, philosopher, or logic symbol."
	)
	var item: LibraryEntry

	@Parameter(
		title: "Action",
		description: "Whether to add the bookmark or remove it. Use add to bookmark, save or favorite the entry, and remove to unbookmark it."
	)
	var action: BookmarkAction

	static var parameterSummary: some ParameterSummary {
		Summary("\(\.$action) bookmark for \(\.$item)")
	}

	static let supportedModes: IntentModes = [
		.background,
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		let reference = CatalogReference(id: item.id, name: item.name, category: item.category)

		switch action {
			case .add:
				Defaults[.bookmarks].insert(reference)

			case .remove:
				Defaults[.bookmarks].remove(reference)
		}

		return .result()
	}
}
