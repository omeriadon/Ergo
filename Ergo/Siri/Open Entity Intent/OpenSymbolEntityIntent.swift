//
//  OpenSymbolEntityIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct OpenSymbolEntityIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Symbol"

	@Parameter(title: "Symbol", description: "The symbol to open in Ergo")
	var target: SymbolEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(category: .symbols, id: target.id)

		return .result()
	}
}
