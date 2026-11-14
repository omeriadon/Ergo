//
//  Library Navigation.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import AppIntents
import Defaults
import ErgoCatalog
import Foundation
import SwiftUI

/// all the content middle views library can go to
nonisolated enum LibraryContent: String, Hashable, CaseIterable, Codable, Sendable, Defaults.Serializable, AppEnum, LosslessStringConvertible {
	var description: String {
		rawValue.capitalized
	}

	init?(_ description: String) {
		self.init(rawValue: description.lowercased())
	}

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

	var title: String {
		rawValue.capitalized
	}

	var themeColor: Color {
		CategoryTheme.color(for: self)
	}

	static var typeDisplayRepresentation: TypeDisplayRepresentation {
		TypeDisplayRepresentation(name: "Library Category")
	}

	static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.biases: DisplayRepresentation(title: "Biases", image: .init(systemName: "distribute.vertical.center")),
		.razors: DisplayRepresentation(title: "Razors", image: .init(systemName: "scissors")),
		.symbols: DisplayRepresentation(title: "Symbols", image: .init(systemName: "f.cursive")),
		.concepts: DisplayRepresentation(title: "Concepts", image: .init(systemName: "book.closed")),
		.paradoxes: DisplayRepresentation(title: "Paradoxes", image: .init(systemName: "infinity")),
		.philosophers: DisplayRepresentation(title: "Philosophers", image: .init(systemName: "brain.head.profile")),
		.fallacies: DisplayRepresentation(title: "Fallacies", image: .init(systemName: "repeat.badge.xmark")),
		.arguments: DisplayRepresentation(title: "Arguments", image: .init(systemName: "text.bubble")),
	]
}

/// the actual library route, middle plus detail
nonisolated enum LibraryRoute: Hashable, Codable, Defaults.Serializable {
	case category(LibraryContent)
	case detail(category: LibraryContent, id: String)

	case symbols(filter: SymbolSearchToken)
	case biases(filter: BiasTag)
	case razors(filter: RazorTag)
	case paradoxes(filter: ParadoxTag)
	case concepts(filter: ConceptTag)
	case fallacies(filter: FallacyTag)
	case arguments(filter: ArgumentTag)

	case bookmarks

	/// Spaced-repetition practice over the library and the course
	case practice

	var listCategory: LibraryContent? {
		switch self {
			case let .category(category):
				category

			case .symbols:
				.symbols

			case .biases:
				.biases

			case .razors:
				.razors

			case .paradoxes:
				.paradoxes

			case .concepts:
				.concepts

			case .fallacies:
				.fallacies

			case .arguments:
				.arguments

			case .detail, .bookmarks, .practice:
				nil
		}
	}
}
