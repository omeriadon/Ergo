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
			intent: OpenBiasesIntent(),
			phrases: [
				"Show my biases in \(.applicationName)",
				"Open biases in \(.applicationName)",
			],
			shortTitle: "Open Biases",
			systemImageName: "distribute.vertical.center"
		)

		AppShortcut(
			intent: OpenRazorsIntent(),
			phrases: [
				"Show my razors in \(.applicationName)",
				"Open razors in \(.applicationName)",
			],
			shortTitle: "Open Razors",
			systemImageName: "scissors"
		)

		AppShortcut(
			intent: OpenParadoxesIntent(),
			phrases: [
				"Show my paradoxes in \(.applicationName)",
				"Open paradoxes in \(.applicationName)",
			],
			shortTitle: "Open Paradoxes",
			systemImageName: "infinity"
		)

		AppShortcut(
			intent: OpenConceptsIntent(),
			phrases: [
				"Show my concepts in \(.applicationName)",
				"Open concepts in \(.applicationName)",
			],
			shortTitle: "Open Concepts",
			systemImageName: "book.closed"
		)

		AppShortcut(
			intent: OpenFallaciesIntent(),
			phrases: [
				"Show my fallacies in \(.applicationName)",
				"Open fallacies in \(.applicationName)",
			],
			shortTitle: "Open Fallacies",
			systemImageName: "repeat.badge.xmark"
		)

		AppShortcut(
			intent: OpenArgumentsIntent(),
			phrases: [
				"Show my arguments in \(.applicationName)",
				"Open arguments in \(.applicationName)",
			],
			shortTitle: "Open Arguments",
			systemImageName: "text.bubble"
		)

		AppShortcut(
			intent: OpenSymbolsIntent(),
			phrases: [
				"Show my symbols in \(.applicationName)",
				"Open symbols in \(.applicationName)",
			],
			shortTitle: "Open Symbols",
			systemImageName: "f.cursive"
		)

		AppShortcut(
			intent: OpenPhilosophersIntent(),
			phrases: [
				"Show my philosophers in \(.applicationName)",
				"Open philosophers in \(.applicationName)",
			],
			shortTitle: "Open Philosophers",
			systemImageName: "brain.head.profile"
		)
	}
}
