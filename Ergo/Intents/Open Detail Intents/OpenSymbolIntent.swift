//
//  OpenSymbolIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// OpenSymbolIntent.swift

import AppIntents

@AppIntent(.tool)
struct OpenSymbolIntent: OpenIntent {
	static var title: LocalizedStringResource = "Open Symbol"

	static var description = IntentDescription(
		"Opens a specific logic symbol in Ergo."
	)

	static var isDiscoverable: Bool {
		false
	}

	@Parameter(title: "Symbol", description: "The target symbol entity to open")
	var target: SymbolEntity

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.openLibraryEntry(
			category: .symbols,
			id: target.id
		)

		return .result()
	}
}
