//
//  ItemOfTheDayItem.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoCatalog
import Foundation

/// An item of the day, whole. Switch on it for the kind's own properties. The widgets compile this too, so it
/// leans on the catalog's models alone.
nonisolated enum ItemOfTheDayItem: Sendable {
	case bias(Bias)
	case concept(Concept)
	case fallacy(Fallacy)
	case paradox(Paradox)
	case philosopher(Philosopher)
	case razor(Razor)
	case argument(Argument)

	var reference: CatalogReference {
		switch self {
			case let .bias(item): CatalogReference(id: item.id, name: item.name, category: .biases)
			case let .concept(item): CatalogReference(id: item.id, name: item.name, category: .concepts)
			case let .fallacy(item): CatalogReference(id: item.id, name: item.name, category: .fallacies)
			case let .paradox(item): CatalogReference(id: item.id, name: item.name, category: .paradoxes)
			case let .philosopher(item): CatalogReference(id: item.id, name: item.name, category: .philosophers)
			case let .razor(item): CatalogReference(id: item.id, name: item.name, category: .razors)
			case let .argument(item): CatalogReference(id: item.id, name: item.name, category: .arguments)
		}
	}

	// MARK: - Loading

	/// `entryID` is `category/id`, as `ItemOfTheDay` gives it. Only that kind's file is read, since a widget has little memory.
	/// Nil if the library doesn't have it.
	static func load(_ entryID: String, index: CatalogIndex) -> ItemOfTheDayItem? {
		let parts = entryID.split(separator: "/", maxSplits: 1).map(String.init)
		guard parts.count == 2 else { return nil }
		let id = parts[1]

		switch parts[0] {
			case "biases": return find(id, in: "biases", index: index, \BiasCatalog.biases).map(Self.bias)
			case "concepts": return find(id, in: "concepts", index: index, \ConceptCatalog.concepts).map(Self.concept)
			case "fallacies": return find(id, in: "fallacies", index: index, \FallacyCatalog.fallacies).map(Self.fallacy)
			case "paradoxes": return find(id, in: "paradoxes", index: index, \ParadoxCatalog.paradoxes).map(Self.paradox)
			case "philosophers": return find(id, in: "philosophers", index: index, \PhilosopherCatalog.philosophers).map(Self.philosopher)
			case "razors": return find(id, in: "razors", index: index, \RazorCatalog.razors).map(Self.razor)
			case "arguments": return find(id, in: "arguments", index: index, \ArgumentCatalog.arguments).map(Self.argument)
			default: return nil
		}
	}

	private static func find<Catalog: Decodable & Sendable, Item: Identifiable>(
		_ id: String,
		in file: String,
		index: CatalogIndex,
		_ items: KeyPath<Catalog, [Item]>
	) -> Item? where Item.ID == String {
		let catalog: Catalog? = try? CatalogStore.decode(file, using: index)
		return catalog?[keyPath: items].first { $0.id == id }
	}

	// MARK: - Link

	/// What a tap on the widget opens: `ergo://library/<category>/<id>`
	var url: URL? {
		let reference = reference
		return URL(string: "ergo://library/\(reference.category.rawValue)/\(reference.id)")
	}

	static func entry(from url: URL) -> (category: LibraryContent, id: String)? {
		guard url.scheme == "ergo", url.host == "library" else { return nil }
		let parts = url.pathComponents.filter { $0 != "/" }
		guard parts.count == 2, let category = LibraryContent(rawValue: parts[0]) else { return nil }
		return (category, parts[1])
	}
}
