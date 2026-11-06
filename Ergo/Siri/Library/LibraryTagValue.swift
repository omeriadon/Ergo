//
//  LibraryTagValue.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

/// Any tag or group a library list can be filtered by, across every category.
///
/// This is one entity with a query rather than a union of the tag enums: Shortcuts can offer "Add Item" and a
/// searchable picker for a list of entities, but not for a list of union values.
nonisolated struct LibraryTagValue: AppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Library Filter"

	static let defaultQuery = LibraryTagQuery()

	let id: String
	let category: LibraryContent
	let libraryFilter: LibraryFilter

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(libraryFilter.title)",
			subtitle: "\(category.description)",
			image: .init(systemName: libraryFilter.kind.systemImage)
		)
	}

	init(category: LibraryContent, filter: LibraryFilter) {
		id = "\(category.rawValue):\(filter.id)"
		self.category = category
		libraryFilter = filter
	}
}

extension LibraryTagValue {
	/// Every filter the library can apply, in the order the lists show them
	static let all: [LibraryTagValue] = {
		let filters: [(LibraryContent, [LibraryFilter])] = [
			(.biases, BiasTag.libraryFilters),
			(.concepts, ConceptTag.libraryFilters),
			(.fallacies, FallacyTag.libraryFilters),
			(.paradoxes, ParadoxTag.libraryFilters),
			(.razors, RazorTag.libraryFilters),
			(.arguments, ArgumentTag.libraryFilters),
			(.symbols, SymbolGroup.libraryFilters + SymbolTag.libraryFilters),
		]

		return filters.flatMap { category, filters in
			filters.map { LibraryTagValue(category: category, filter: $0) }
		}
	}()

	/// The entity for a list filter. Nil for filters the intent can't express.
	static func value(for filter: LibraryFilter, in category: LibraryContent) -> LibraryTagValue? {
		let id = LibraryTagValue(category: category, filter: filter).id
		return all.first { $0.id == id }
	}
}

nonisolated struct LibraryTagQuery: EntityStringQuery {
	func entities(for identifiers: [String]) async throws -> [LibraryTagValue] {
		LibraryTagValue.all.filter { identifiers.contains($0.id) }
	}

	func entities(matching string: String) async throws -> [LibraryTagValue] {
		let normalized = string.normalizedTagText

		return LibraryTagValue.all.filter { value in
			value.libraryFilter.title.localizedCaseInsensitiveContains(string)
				|| value.libraryFilter.matches(term: string)
				|| value.category.description.normalizedTagText == normalized
		}
	}

	func suggestedEntities() async throws -> [LibraryTagValue] {
		LibraryTagValue.all
	}
}
