import Foundation

typealias CatalogSearchField = (text: String, weight: Double)

struct LibrarySearchEntry: Identifiable {
	let id: String
	let name: String
	let category: LibraryContent
	let searchFields: [CatalogSearchField]
}

private func exampleFields(_ examples: [Example]) -> [CatalogSearchField] {
	examples.flatMap { example in
		[(example.text, 0.5)] + (example.note.map { [($0, 0.5)] } ?? [])
	}
}

extension Bias {
	var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5), (body, 0.5)] +
			exampleFields(examples) +
			counters.map { ($0, 0.5) } + limitations.map { ($0, 0.5) } +
			(evidenceNote.map { [($0, 0.5)] } ?? []) + tags.map { ($0.title, 0.5) }
	}
}

extension Razor {
	var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5), (body, 0.5), (lensQuestion, 0.5)] +
			exampleFields(examples) + limitations.map { ($0, 0.5) } +
			tags.map { ($0.title, 0.5) }
	}
}

extension Fallacy {
	var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5), (body, 0.5)] +
			(detectionCriteria.map { [($0, 0.5)] } ?? []) +
			exampleFields(examples) +
			doesNotCountWhen.map { ($0, 0.5) } + tags.map { ($0.title, 0.5) }
	}
}

extension LogicSymbol {
	var searchFields: [CatalogSearchField] {
		[(name, 1.0), (glyph, 1.0)] + aliases.map { ($0, 0.9) } +
			alternateGlyphs.map { ($0, 1.0) } + shortcodes.map { ($0, 0.9) } +
			englishReadings.map { ($0, 0.7) } +
			[(summary, 0.5), (body, 0.5), (group.rawValue, 0.5)] +
			exampleFields(examples) + limitations.map { ($0, 0.5) } +
			tags.map { ($0.title, 0.5) }
	}
}

private func referenceFields(_ references: [CatalogReference]) -> [CatalogSearchField] {
	references.map { ($0.name, 0.7) }
}

extension Concept {
	var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5), (body, 0.5)] +
			(origin.map { [($0, 0.5)] } ?? []) + referenceFields(keyFigures) +
			exampleFields(examples) + commonMisreadings.map { ($0, 0.5) } +
			criticisms.map { ($0, 0.5) } + tags.map { ($0.title, 0.5) }
	}
}

extension Paradox {
	var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5), (body, 0.5)] +
			(origin.map { [($0, 0.5)] } ?? []) + referenceFields(keyFigures) +
			exampleFields(examples) + commonMisreadings.map { ($0, 0.5) } +
			criticisms.map { ($0, 0.5) } + tags.map { ($0.title, 0.5) }
	}
}

extension Argument {
	var searchFields: [CatalogSearchField] {
		[(name, 1.0)] + aliases.map { ($0, 0.9) } +
			[(summary, 0.5), (body, 0.5), (conclusion, 0.5)] +
			(origin.map { [($0, 0.5)] } ?? []) + referenceFields(keyFigures) +
			premises.map { ($0, 0.5) } + assumptions.map { ($0, 0.5) } +
			objections.flatMap { [($0.objection, 0.5), ($0.reply, 0.5)] } +
			exampleFields(examples) + tags.map { ($0.title, 0.5) }
	}
}

private func yearFields(_ year: Int) -> [CatalogSearchField] {
	var fields: [CatalogSearchField] = [(String(year), 0.7)]
	if year < 0 {
		fields.append(("\(abs(year)) BC", 0.7))
		fields.append(("\(abs(year)) BCE", 0.7))
	}
	return fields
}

extension Philosopher {
	var searchFields: [CatalogSearchField] {
		var fields: [CatalogSearchField] = [
			(name, 1.0),
			(summary, 0.5),
			(body, 0.5),
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
