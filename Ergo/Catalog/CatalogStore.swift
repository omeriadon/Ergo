//
//  CatalogStore.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class CatalogStore {
	private(set) var biases: BiasCatalog = .init(biases: [])
	private(set) var concepts: ConceptCatalog = .init(concepts: [])
	private(set) var fallacies: FallacyCatalog = .init(fallacies: [])
	private(set) var razors: RazorCatalog = .init(razors: [])
	private(set) var logicSymbols: LogicSymbolCatalog = .init(symbols: [])
	private(set) var paradoxes: ParadoxCatalog = .init(paradoxes: [])
	private(set) var philosophers: PhilosopherCatalog = .init(philosophers: [])
	private(set) var arguments: ArgumentCatalog = .init(arguments: [])

	private(set) var isLoaded = false

	func load() async throws {
		async let pendingIndex = Self.makeIndex()
		let newIndex = try await pendingIndex
		async let newBiases: BiasCatalog = Self.decode("biases", using: newIndex)
		async let newConcepts: ConceptCatalog = Self.decode("concepts", using: newIndex)
		async let newFallacies: FallacyCatalog = Self.decode("fallacies", using: newIndex)
		async let newRazors: RazorCatalog = Self.decode("razors", using: newIndex)
		async let newLogicSymbols: LogicSymbolCatalog = Self.decode("symbols", using: newIndex)
		async let newParadoxes: ParadoxCatalog = Self.decode("paradoxes", using: newIndex)
		async let newPhilosophers: PhilosopherCatalog = Self.decode("philosophers", using: newIndex)
		async let newArguments: ArgumentCatalog = Self.decode("arguments", using: newIndex)

		let results = try await (
			newBiases,
			newConcepts,
			newFallacies,
			newRazors,
			newLogicSymbols,
			newParadoxes,
			newPhilosophers,
			newArguments
		)
		try Self.validate(concepts: results.1, paradoxes: results.5, arguments: results.7)

		biases = results.0
		concepts = results.1
		fallacies = results.2
		razors = results.3
		logicSymbols = results.4
		paradoxes = results.5
		philosophers = results.6
		arguments = results.7
		index = newIndex
		isLoaded = true
	}

	private(set) var index = CatalogIndex()

	func rebuildIndex() throws {
		var newIndex = CatalogIndex()

		try newIndex.register(
			logicSymbols.symbols,
			category: .symbols,
			id: \.id,
			name: \.name
		)

		try newIndex.register(fallacies.fallacies, category: .fallacies, id: \.id, name: \.name)
		try newIndex.register(razors.razors, category: .razors, id: \.id, name: \.name)
		try newIndex.register(biases.biases, category: .biases, id: \.id, name: \.name)
		try newIndex.register(concepts.concepts, category: .concepts, id: \.id, name: \.name)
		try newIndex.register(paradoxes.paradoxes, category: .paradoxes, id: \.id, name: \.name)
		try newIndex.register(philosophers.philosophers, category: .philosophers, id: \.id, name: \.name)
		try newIndex.register(arguments.arguments, category: .arguments, id: \.id, name: \.name)

		index = newIndex
	}

	private nonisolated static func decode<T: Decodable & Sendable>(
		_ name: String,
		using index: CatalogIndex
	) throws -> T {
		guard let url = Bundle.main.url(
			forResource: name,
			withExtension: "json"
		) else {
			throw CocoaError(.fileNoSuchFile)
		}

		let data = try Data(contentsOf: url)
		let decoder = JSONDecoder()
		decoder.userInfo[.catalogIndex] = index
		return try decoder.decode(T.self, from: data)
	}

	private nonisolated static func makeIndex() throws -> CatalogIndex {
		var newIndex = CatalogIndex()
		try registerMetadata("symbols", category: .symbols, in: &newIndex)
		try registerMetadata("fallacies", category: .fallacies, in: &newIndex)
		try registerMetadata("razors", category: .razors, in: &newIndex)
		try registerMetadata("biases", category: .biases, in: &newIndex)
		try registerMetadata("concepts", category: .concepts, in: &newIndex)
		try registerMetadata("paradoxes", category: .paradoxes, in: &newIndex)
		try registerMetadata("philosophers", category: .philosophers, in: &newIndex)
		try registerMetadata("arguments", category: .arguments, in: &newIndex)
		return newIndex
	}

	private nonisolated static func registerMetadata(
		_ name: String,
		category: LibraryContent,
		in index: inout CatalogIndex
	) throws {
		guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
			throw CocoaError(.fileNoSuchFile)
		}

		let data = try Data(contentsOf: url)
		let metadata = try JSONDecoder().decode([String: [CatalogMetadata]].self, from: data)
		guard let entries = metadata[name] else {
			throw DecodingError.dataCorrupted(.init(
				codingPath: [],
				debugDescription: "Missing catalog collection: \(name)"
			))
		}
		try index.register(entries, category: category, id: \.id, name: \.name)
	}

	private nonisolated static func validate(
		concepts: ConceptCatalog,
		paradoxes: ParadoxCatalog,
		arguments: ArgumentCatalog
	) throws {
		for entry in concepts.concepts where entry.keyFigures.contains(where: { $0.category != .philosophers }) {
			throw CatalogIndexError.invalidKeyFigure(entry.id)
		}

		for entry in paradoxes.paradoxes where entry.keyFigures.contains(where: { $0.category != .philosophers }) {
			throw CatalogIndexError.invalidKeyFigure(entry.id)
		}
		for entry in arguments.arguments where entry.keyFigures.contains(where: { $0.category != .philosophers }) {
			throw CatalogIndexError.invalidKeyFigure(entry.id)
		}
	}
}

private struct CatalogMetadata: Decodable, Sendable {
	let id: String
	let name: String
}
