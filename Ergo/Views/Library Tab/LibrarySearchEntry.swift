import Foundation

nonisolated struct LibrarySearchEntry: Identifiable, Sendable {
	let id: String
	let name: String
	let category: LibraryContent
	let searchFields: [CatalogSearchField]
}

extension Bias {
	nonisolated var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5)]
	}
}

extension Razor {
	nonisolated var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5)]
	}
}

extension Fallacy {
	nonisolated var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5)]
	}
}

extension LogicSymbol {
	nonisolated var searchFields: [CatalogSearchField] {
		[(name, 1.0), (glyph, 1.0)] + aliases.map { ($0, 0.9) } +
			alternateGlyphs.map { ($0, 1.0) } + shortcodes.map { ($0, 0.9) } +
			englishReadings.map { ($0, 0.7) } +
			[(summary, 0.5)]
	}
}

extension Concept {
	nonisolated var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5)]
	}
}

extension Paradox {
	nonisolated var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5)]
	}
}

extension Argument {
	nonisolated var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5)]
	}
}

extension Philosopher {
	nonisolated var searchFields: [CatalogSearchField] {
		var fields: [CatalogSearchField] = [
			(name, 1.0),
			(summary, 0.5),
		]
		fields += yearFields(birthYear)
		if let deathYear {
			fields += yearFields(deathYear)
		} else {
			fields.append(("present", 0.7))
		}
		return fields
	}
}

private nonisolated func yearFields(_ year: Int) -> [CatalogSearchField] {
	var fields: [CatalogSearchField] = [(String(year), 0.7)]
	if year < 0 {
		fields.append(("\(abs(year)) BC", 0.7))
		fields.append(("\(abs(year)) BCE", 0.7))
	}
	return fields
}

extension CatalogStore {
	/// Everything in the library, as something to search
	var searchEntries: [LibrarySearchEntry] {
		let biasResults = biases.biases.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .biases,
				searchFields: entry.searchFields
			)
		}
		let conceptResults = concepts.concepts.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .concepts,
				searchFields: entry.searchFields
			)
		}
		let fallacyResults = fallacies.fallacies.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .fallacies,
				searchFields: entry.searchFields
			)
		}
		let symbolResults = logicSymbols.symbols.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .symbols,
				searchFields: entry.searchFields
			)
		}
		let paradoxResults = paradoxes.paradoxes.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .paradoxes,
				searchFields: entry.searchFields
			)
		}
		let philosopherResults = philosophers.philosophers.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .philosophers,
				searchFields: entry.searchFields
			)
		}
		let razorResults = razors.razors.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .razors,
				searchFields: entry.searchFields
			)
		}
		let argumentResults = arguments.arguments.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .arguments,
				searchFields: entry.searchFields
			)
		}
		var entries = biasResults
		entries += conceptResults
		entries += fallacyResults
		entries += symbolResults
		entries += paradoxResults
		entries += philosopherResults
		entries += razorResults
		entries += argumentResults
		return entries
	}
}
