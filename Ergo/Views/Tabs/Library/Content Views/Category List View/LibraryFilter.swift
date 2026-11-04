//
//  LibraryFilter.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import Foundation

nonisolated struct LibraryFilter: Hashable, Identifiable, Sendable {
	enum Kind: Int, Hashable, Comparable, CaseIterable, Sendable {
		case group
		case tag

		static func < (lhs: Kind, rhs: Kind) -> Bool {
			lhs.rawValue < rhs.rawValue
		}

		var title: String {
			switch self {
				case .group:
					"Groups"

				case .tag:
					"Tags"
			}
		}

		var systemImage: String {
			switch self {
				case .group:
					"square.grid.2x2"

				case .tag:
					"tag"
			}
		}

		var tokenImage: String {
			switch self {
				case .group:
					"sum"

				case .tag:
					"tag"
			}
		}
	}

	let kind: Kind
	let key: String
	let title: String

	var id: String {
		"\(kind.rawValue):\(key)"
	}

	func matches(term: String) -> Bool {
		let normalized = term.normalizedTagText

		return title.normalizedTagText == normalized
			|| key.normalizedTagText == normalized
	}
}

extension LibraryTag {
	nonisolated var libraryFilter: LibraryFilter {
		LibraryFilter(kind: .tag, key: rawValue, title: title)
	}

	nonisolated static var libraryFilters: [LibraryFilter] {
		allCases.map(\.libraryFilter)
	}
}

extension SymbolGroup {
	nonisolated var libraryFilter: LibraryFilter {
		LibraryFilter(kind: .group, key: rawValue, title: rawValue.capitalized)
	}

	nonisolated static var libraryFilters: [LibraryFilter] {
		allCases.map(\.libraryFilter)
	}
}

extension SymbolSearchToken {
	nonisolated var libraryFilter: LibraryFilter {
		switch self {
			case let .group(group):
				group.libraryFilter

			case let .tag(tag):
				tag.libraryFilter
		}
	}
}
