//
//  App Shortcuts.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import Foundation

struct ErgoShortcuts: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: OpenTabIntent(),
			phrases: [
				"Open a tab in \(.applicationName)",
			],
			shortTitle: "Open A Tab",
			systemImageName: "square.stack"
		)

		AppShortcut(
			intent: ShowLibraryListIntent(),
			phrases: [
				"Show my \(\.$category) in \(.applicationName)",
				"Open \(\.$category) in \(.applicationName)",
			],
			shortTitle: "Show Library List",
			systemImageName: "books.vertical"
		)
	}
}
