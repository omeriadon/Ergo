//
//  OpenSymbolEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

/// Plain `OpenIntent` so Spotlight can open an indexed entity. Not a tool and hidden from Shortcuts: Siri and Shortcuts open entries through `OpenLibraryEntryIntent`.
struct OpenSymbolEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Symbol"

	static let isDiscoverable = false

	@Parameter(title: "Symbol", description: "The symbol to open in Ergo")
	var target: SymbolEntity

	@Dependency
	private var navigation: NavigationManager

	static let supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .symbols, id: target.id)

		return .result()
	}
}
