//
//  Library Navigation.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Foundation

// MARK: - Library

/// all the content middle views library can go to
enum LibraryContent: Hashable {
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
}

// MARK: - Symbol

enum SymbolTag: String, Hashable, Identifiable, CaseIterable {
	case Modal
	case Predicate
	case Proof
	case Propositional
	case Set

	var desciption: String {
		switch self {
			case .Modal:
				"Modal logic"
			case .Predicate:
				"Predicate logic"
			case .Proof:
				"Proof notation"
			case .Propositional:
				"Propotisional logic"
			case .Set:
				"Set notation"
		}
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
				tag.rawValue
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
