//
//  Library Navigation.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import Foundation

// MARK: - Library

/// all the content middle views library can go to
nonisolated enum LibraryContent: Hashable, Codable, Sendable, Defaults.Serializable {
	case biases
	case concepts
	case fallacies
	case symbols
	case paradoxes
	case philosophers
	case razors
}

/// the actual library route, middle plus detail
enum LibraryRoute: Hashable {
	case category(LibraryContent)
	case detail(category: LibraryContent, id: String)

	case symbols(filter: SymbolSearchToken)
}

nonisolated struct CatalogReference: Hashable, Identifiable, Codable, Sendable, Defaults.Serializable {
	let id: String
	let name: String
	let category: LibraryContent

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case category
	}

	init(id: String, name: String, category: LibraryContent) {
		self.id = id
		self.name = name
		self.category = category
	}

	nonisolated init(id: String, from decoder: Decoder) throws {
		guard let index = decoder.userInfo[.catalogIndex] as? CatalogIndex else {
			throw CatalogIndexError.missingID(id)
		}

		self = try index.reference(for: id)
	}

	init(from decoder: Decoder) throws {
		if let id = try? decoder.singleValueContainer().decode(String.self) {
			self = try CatalogReference(id: id, from: decoder)
			return
		}

		let container = try decoder.container(keyedBy: CodingKeys.self)
		let decodedID = try container.decode(String.self, forKey: .id)
		if decoder.userInfo[.catalogIndex] != nil {
			self = try CatalogReference(id: decodedID, from: decoder)
			return
		}

		id = decodedID
		name = try container.decode(String.self, forKey: .name)
		category = try container.decode(LibraryContent.self, forKey: .category)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(name, forKey: .name)
		try container.encode(category, forKey: .category)
	}

	var route: LibraryRoute {
		.detail(category: category, id: id)
	}
}

// MARK: - Symbol

enum SymbolTag: String, Codable, Hashable, Identifiable, CaseIterable, Sendable {
	case modalLogic = "modal-logic"
	case predicateLogic = "predicate-logic"
	case proofNotation = "proof-notation"
	case propositionalLogic = "propositional-logic"
	case setNotation = "set-notation"

	var desciption: String {
		switch self {
			case .modalLogic:
				"Modal logic"
			case .predicateLogic:
				"Predicate logic"
			case .proofNotation:
				"Proof notation"
			case .propositionalLogic:
				"Propositional logic"
			case .setNotation:
				"Set notation"
		}
	}

	var title: String {
		desciption
	}

	var id: Self {
		self
	}
}

enum SymbolSearchToken: Hashable, Identifiable {
	case group(SymbolGroup)
	case tag(SymbolTag)

	var id: Self {
		self
	}

	var title: String {
		switch self {
			case let .group(group):
				group.rawValue.capitalized

			case let .tag(tag):
				tag.title
		}
	}

	var symbol: String {
		switch self {
			case .group:
				"sum"

			case .tag:
				"tag"
		}
	}
}
