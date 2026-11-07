//
//  LookUpLibraryIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import AppIntents
import ErgoCatalog

/// Answers with what the library says rather than opening it. The search itself is `LibraryCatalog.search`, the same
/// function the server's `search_library` tool runs for Ask, so Siri, Shortcuts and the model all look things up alike.
@AppIntent(.tool)
struct LookUpLibraryIntent: AppIntent {
	static let title: LocalizedStringResource = "Look Up in Library"

	static let description = IntentDescription(
		"Finds what Ergo's library says about a bias, concept, fallacy, paradox, razor, argument, philosopher, or logic symbol, and answers with a summary of each match."
	)

	@Parameter(title: "Query", description: "What to look up, such as straw man or confirmation bias.")
	var query: String

	func perform() async throws -> some IntentResult & ReturnsValue<String> {
		let found = LibraryCatalog.shared?.search(query, limit: 5) ?? []
		return .result(value: found.map { "\($0.name): \($0.summary)" }.joined(separator: "\n"))
	}
}
