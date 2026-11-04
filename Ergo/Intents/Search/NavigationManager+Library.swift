//
//  NavigationManager+Library.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

extension NavigationManager {
	var currentLibraryCategory: LibraryContent? {
		switch libraryPath.last {
			case let .category(category), let .detail(category, _):
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

			case .bookmarks, nil:
				nil
		}
	}

	func librarySearchBinding(for category: LibraryContent) -> Binding<String> {
		Binding(
			get: {
				self.librarySearchText[category, default: ""]
			},
			set: { newValue in
				self.librarySearchText[category] = newValue
			}
		)
	}

	func libraryTagRoute(for term: String) -> LibraryRoute? {
		let matchers: [(LibraryContent, () -> LibraryRoute?)] = [
			(.biases, { BiasTag.match(term).map(LibraryRoute.biases) }),
			(.razors, { RazorTag.match(term).map(LibraryRoute.razors) }),
			(.paradoxes, { ParadoxTag.match(term).map(LibraryRoute.paradoxes) }),
			(.concepts, { ConceptTag.match(term).map(LibraryRoute.concepts) }),
			(.fallacies, { FallacyTag.match(term).map(LibraryRoute.fallacies) }),
			(.arguments, { ArgumentTag.match(term).map(LibraryRoute.arguments) }),
			(.symbols, {
				if let tag = SymbolTag.match(term) {
					return .symbols(filter: .tag(tag))
				}

				let normalized = term.normalizedTagText

				if let group = SymbolGroup.allCases.first(where: { $0.rawValue == normalized }) {
					return .symbols(filter: .group(group))
				}

				return nil
			}),
		]

		let current = currentLibraryCategory

		let ordered = matchers.filter { $0.0 == current }
			+ matchers.filter { $0.0 != current }

		for (_, makeRoute) in ordered {
			if let route = makeRoute() {
				return route
			}
		}

		return nil
	}

	func applyLibrarySearch(term: String) {
		selectedTab = .library

		let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !trimmed.isEmpty else {
			return
		}

		if let route = libraryTagRoute(for: trimmed) {
			libraryPath.append(route)
		} else if let category = currentLibraryCategory {
			librarySearchText[category] = trimmed
		} else {
			libraryPath.removeAll()
			libraryGeneralSearchText = trimmed
		}
	}
}
