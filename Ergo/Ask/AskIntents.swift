//
//  AskIntents.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import AppIntents
import ErgoCatalog
import ErgoProtocol
import Foundation

/// Runs what a link or a button in an answer asks for, through the same App Intents Siri and Shortcuts use
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

	static func run(_ intent: AskIntent, navigation: NavigationManager, catalog: CatalogStore) async {
		switch intent {
			case let .openLibraryEntry(category, id):
				guard let category = LibraryContent(rawValue: category), let entry = IntentDonations.entry(category: category, id: id, catalog: catalog) else { return }
				let intent = OpenLibraryEntryIntent()
				intent.target = entry
				_ = try? await intent.perform()

			case let .showLibraryList(category):
				guard let category = LibraryContent(rawValue: category) else { return }
				let intent = ShowLibraryListIntent()
				intent.category = category
				_ = try? await intent.perform()

			case .openBookmarks:
				// Siri brings the app forward to wherever the library is, a button has to go there itself
				navigation.selectedTab = .library
				_ = try? await OpenBookmarksIntent().perform()

			case let .openTab(tab):
				guard let tab = AppTab(rawValue: tab) else { return }
				let intent = OpenTabIntent()
				intent.tab = tab
				_ = try? await intent.perform()

			case .unknown:
				break
		}
	}
}
