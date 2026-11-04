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
