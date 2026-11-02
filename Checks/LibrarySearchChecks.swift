// Run with Xcode MCP RunCodeSnippet in the context of LibraryTabView.swift.
// This file is outside the app target and exercises the actual search functions.
import Foundation

@MainActor
func checkLibrarySearch() async throws {
	let store = CatalogStore()
	try await store.load()
	let library = LibraryTabView()
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
	precondition(library.searchLibrary([incidental, named], query: "Arbitrary").first?.id == named.id)
	precondition(library.searchLibrary([named], query: "arbtr").first?.id == named.id)
	precondition(library.searchLibrary([named], query: "  Arbitrary\n").first?.id == named.id)
	precondition(library.searchLibrary([named], query: " \n ").isEmpty)
	for text in ["alias phrase", "summary phrase", "body phrase"] {
		let entry = LibrarySearchEntry(
			id: text,
			name: "Other",
			category: .concepts,
			searchFields: [("Other", 1.0), (text, 0.5)]
		)
		precondition(library.searchLibrary([entry], query: text).first?.id == entry.id)
	}

	let aristotle = store.philosophers.philosophers.first { $0.name == "Aristotle" }!
	for query in ["Aristotle", "384", "-384", "384 BC", "384 BCE", "322"] {
		precondition(PhilosophersView().searchPhilosophers([aristotle], query: query).first?.id == aristotle.id)
	}
	precondition(aristotle.searchFields.contains { $0.text == aristotle.body })
	let living = store.philosophers.philosophers.first { $0.deathYear == nil }!
	precondition(living.searchFields.contains { $0.text == "present" })
	precondition(!living.searchFields.contains { $0.text == "0" })

	let conjunction = store.logicSymbols.symbols.first { $0.name == "Conjunction" }!
	for query in [conjunction.glyph] + conjunction.alternateGlyphs + conjunction.shortcodes + conjunction.englishReadings {
		precondition(SymbolsView().searchSymbols([conjunction], query: query).first?.id == conjunction.id)
	}
	let concept = store.concepts.concepts.first { $0.origin != nil && !$0.keyFigures.isEmpty }!
	precondition(concept.searchFields.contains { $0.text == concept.origin })
	precondition(concept.searchFields.contains { $0.text == concept.keyFigures[0].name })
	precondition(concept.searchFields.contains { $0.text == concept.summary })
	precondition(concept.searchFields.contains { $0.text == concept.body })
	for alias in concept.aliases {
		precondition(concept.searchFields.contains { $0.text == alias })
	}

	let emptyQuery = " \n "
	precondition(BiasesView().searchBiases(store.biases.biases, query: emptyQuery).map(\.id) == store.biases.biases.map(\.id))
	precondition(ConceptsView().searchConcepts(store.concepts.concepts, query: emptyQuery).map(\.id) == store.concepts.concepts.map(\.id))
	precondition(FallaciesView().searchFallacies(store.fallacies.fallacies, query: emptyQuery).map(\.id) == store.fallacies.fallacies.map(\.id))
	precondition(SymbolsView().searchSymbols(store.logicSymbols.symbols, query: emptyQuery).map(\.id) == store.logicSymbols.symbols.map(\.id))
	precondition(ParadoxesView().searchParadoxes(store.paradoxes.paradoxes, query: emptyQuery).map(\.id) == store.paradoxes.paradoxes.map(\.id))
	precondition(PhilosophersView().searchPhilosophers(store.philosophers.philosophers, query: emptyQuery).map(\.id) == store.philosophers.philosophers.map(\.id))
	precondition(RazorsView().searchRazors(store.razors.razors, query: emptyQuery).map(\.id) == store.razors.razors.map(\.id))
	precondition(ArgumentsView().searchArguments(store.arguments.arguments, query: emptyQuery).map(\.id) == store.arguments.arguments.map(\.id))

	var entries = store.biases.biases.map {
		LibrarySearchEntry(id: $0.id, name: $0.name, category: .biases, searchFields: $0.searchFields)
	}
	entries += store.concepts.concepts.map {
		LibrarySearchEntry(id: $0.id, name: $0.name, category: .concepts, searchFields: $0.searchFields)
	}
	entries += store.fallacies.fallacies.map {
		LibrarySearchEntry(id: $0.id, name: $0.name, category: .fallacies, searchFields: $0.searchFields)
	}
	entries += store.logicSymbols.symbols.map {
		LibrarySearchEntry(id: $0.id, name: $0.name, category: .symbols, searchFields: $0.searchFields)
	}
	entries += store.paradoxes.paradoxes.map {
		LibrarySearchEntry(id: $0.id, name: $0.name, category: .paradoxes, searchFields: $0.searchFields)
	}
	entries += store.philosophers.philosophers.map {
		LibrarySearchEntry(id: $0.id, name: $0.name, category: .philosophers, searchFields: $0.searchFields)
	}
	entries += store.razors.razors.map {
		LibrarySearchEntry(id: $0.id, name: $0.name, category: .razors, searchFields: $0.searchFields)
	}
	entries += store.arguments.arguments.map {
		LibrarySearchEntry(id: $0.id, name: $0.name, category: .arguments, searchFields: $0.searchFields)
	}
	let start = Date()
	let results = library.searchLibrary(entries, query: "Aristotle")
	precondition(results.first?.id == aristotle.id)
	precondition(library.searchLibrary(entries, query: "384 BCE").contains { $0.id == aristotle.id })
	print("Library search checks passed across all eight categories (\(entries.count) entries).")
	print("Full-catalog name search took \(Date().timeIntervalSince(start)) seconds including the year query.")
}

try await checkLibrarySearch()
