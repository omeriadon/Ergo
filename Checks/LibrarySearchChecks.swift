// Run with Xcode MCP RunCodeSnippet in the context of CatalogStore.swift.
// This file is outside the app target and exercises the shared async matcher.
import Foundation

@MainActor
func checkLibrarySearch() async throws {
	let store = CatalogStore()
	try await store.load()
	let named = LibrarySearchEntry(
		id: "named",
		name: "Arbitrary",
		category: .concepts,
		searchFields: [("Arbitrary", 1.0)]
	)
	let incidental = LibrarySearchEntry(
		id: "incidental",
		name: "Other entry",
		category: .concepts,
		searchFields: [("Other entry", 1.0), ("Arbitrary", 0.5)]
	)
	let ranked = try await CatalogSearch.ranked([incidental, named], query: "Arbitrary") {
		precondition(!Thread.isMainThread, "Matching blocked the main thread")
		return $0.searchFields
	}
	precondition(ranked.first?.id == named.id)
	let fuzzy = try await CatalogSearch.ranked([named], query: "arbtr") { $0.searchFields }
	precondition(fuzzy.first?.id == named.id)
	let whitespace = try await CatalogSearch.ranked([named], query: " \n ") { $0.searchFields }
	precondition(whitespace.isEmpty)
	let cancelled = Task {
		try await CatalogSearch.ranked([named], query: "Arbitrary") { $0.searchFields }
	}
	cancelled.cancel()
	do {
		_ = try await cancelled.value
		preconditionFailure("Cancelled search returned results")
	} catch is CancellationError {
		// Expected: cancelled work must not publish results.
	}

	let aristotle = store.philosophers.philosophers.first { $0.name == "Aristotle" }!
	for query in ["Aristotle", "384", "-384", "384 BC", "384 BCE", "322"] {
		let matches = try await CatalogSearch.ranked([aristotle], query: query) { $0.searchFields }
		precondition(matches.first?.id == aristotle.id)
	}
	precondition(!aristotle.searchFields.contains { $0.text == aristotle.body })
	let living = store.philosophers.philosophers.first { $0.deathYear == nil }!
	precondition(living.searchFields.contains { $0.text == "present" })
	precondition(!living.searchFields.contains { $0.text == "0" })

	let conjunction = store.logicSymbols.symbols.first { $0.name == "Conjunction" }!
	for query in [conjunction.glyph] + conjunction.alternateGlyphs + conjunction.shortcodes + conjunction.englishReadings {
		let matches = try await CatalogSearch.ranked([conjunction], query: query) { $0.searchFields }
		precondition(matches.first?.id == conjunction.id)
	}
	for concept in store.concepts.concepts {
		let expected = [concept.name, concept.summary] + concept.aliases
		precondition(concept.searchFields.map(\.text).sorted() == expected.sorted())
	}
	var fields = store.biases.biases.flatMap(\.searchFields)
	fields += store.concepts.concepts.flatMap(\.searchFields)
	fields += store.fallacies.fallacies.flatMap(\.searchFields)
	fields += store.logicSymbols.symbols.flatMap(\.searchFields)
	fields += store.paradoxes.paradoxes.flatMap(\.searchFields)
	fields += store.philosophers.philosophers.flatMap(\.searchFields)
	fields += store.razors.razors.flatMap(\.searchFields)
	fields += store.arguments.arguments.flatMap(\.searchFields)
	precondition(!fields.isEmpty)
	print("Verified short search fields, fuzzy ranking, background execution and cancellation.")
}

try await checkLibrarySearch()
