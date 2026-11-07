//
//  AskIntents.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoCatalog
import ErgoProtocol
import Foundation

/// Does what a link or a button in an answer asks for. Each case calls the same `NavigationManager` method its App Intent
/// does. It can't call the intent itself: an intent's `@Dependency` only resolves inside the system's own intent flow,
/// and `perform()` called from here is a crash.
@MainActor
enum AskIntents {
	private static let libraryIDs: Set<String> = Set(LibraryCatalog.shared?.entries.map { "\($0.category)/\($0.id)" } ?? [])

	/// Whether this version of the app can do it, so a link or a button that goes nowhere is never offered.
	/// The server's library can be newer than the one in this app.
	static func canRun(_ intent: AskIntent) -> Bool {
		switch intent {
			case let .openLibraryEntry(category, id):
				libraryIDs.contains("\(category)/\(id)")
			case let .showLibraryList(category):
				LibraryContent(rawValue: category) != nil
			case .openBookmarks:
				true
			case let .openTab(tab):
				AppTab(rawValue: tab) != nil
			case .unknown:
				false
		}
	}

	static func run(_ intent: AskIntent, navigation: NavigationManager) {
		switch intent {
			case let .openLibraryEntry(category, id):
				guard let category = LibraryContent(rawValue: category) else { return }
				navigation.openLibraryEntry(category: category, id: id)

			case let .showLibraryList(category):
				guard let category = LibraryContent(rawValue: category) else { return }
				navigation.showLibraryList(category)

			case .openBookmarks:
				navigation.selectedTab = .library
				navigation.libraryPath.append(.bookmarks)

			case let .openTab(tab):
				guard let tab = AppTab(rawValue: tab) else { return }
				navigation.selectedTab = tab

			case .unknown:
				break
		}
	}
}
