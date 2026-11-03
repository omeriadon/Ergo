//
//  Library Navigation.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import Foundation

/// all the content middle views library can go to
nonisolated enum LibraryContent: Hashable, Codable, Sendable, Defaults.Serializable {
	case biases
	case concepts
	case fallacies
	case symbols
	case paradoxes
	case philosophers
	case razors
	case arguments

	var symbol: String {
		switch self {
			case .biases:
				"distribute.vertical.center"
			case .razors:
				"scissors"
			case .symbols:
				"f.cursive"
			case .concepts:
				"book.closed"
			case .paradoxes:
				"infinity"
			case .philosophers:
				"brain.head.profile"
			case .fallacies:
				"repeat.badge.xmark"
			case .arguments:
				"text.bubble"
		}
	}
}

/// the actual library route, middle plus detail
enum LibraryRoute: Hashable {
	case category(LibraryContent)
	case detail(category: LibraryContent, id: String)

	case symbols(filter: SymbolSearchToken)
	case biases(filter: BiasTag)
	case razors(filter: RazorTag)
	case paradoxes(filter: ParadoxTag)
	case concepts(filter: ConceptTag)
	case fallacies(filter: FallacyTag)
	case arguments(filter: ArgumentTag)
}
