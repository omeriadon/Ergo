//
//  OpenSymbolsIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import Foundation

struct OpenSymbolsIntent: AppIntent {
	static var title: LocalizedStringResource = "Open Symbols"

	static var description = IntentDescription(
		"Opens the symbols category in Ergo, optionally filtered by tag."
	)

	@Parameter(title: "Filter")
	var filter: SymbolTag?

	static var parameterSummary: some ParameterSummary {
		Summary("Open symbols in Ergo") {
			\.$filter
		}
	}

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.selectedTab = .library

		if let filter {
			navigation.libraryPath.append(.symbols(filter: .tag(filter)))
		} else {
			navigation.libraryPath.append(.category(.symbols))
		}

		return .result()
	}
}

struct SymbolFilterEntity: AppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Symbol Filter"

	static let defaultQuery = SymbolFilterQuery()

	let token: SymbolSearchToken

	var id: String {
		switch token {
			case let .group(group):
				"group:\(group.rawValue)"

			case let .tag(tag):
				"tag:\(tag.rawValue)"
		}
	}

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(token.title)",
			subtitle: "\(token.kindTitle)",
			image: .init(systemName: token.symbol)
		)
	}
}

struct SymbolFilterQuery: EntityQuery {
	func entities(for identifiers: [String]) async throws -> [SymbolFilterEntity] {
		allEntities().filter { identifiers.contains($0.id) }
	}

	func suggestedEntities() async throws -> [SymbolFilterEntity] {
		allEntities()
	}

	private func allEntities() -> [SymbolFilterEntity] {
		let groups = SymbolGroup.allCases.map {
			SymbolFilterEntity(token: .group($0))
		}

		let tags = SymbolTag.allCases.map {
			SymbolFilterEntity(token: .tag($0))
		}

		return groups + tags
	}
}
