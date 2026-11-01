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

	private(set) var isLoaded = false

	func load() async throws {
		async let biases: BiasCatalog = Self.decode("biases")
		async let concepts: ConceptCatalog = Self.decode("concepts")
		async let fallacies: FallacyCatalog = Self.decode("fallacies")
		async let razors: RazorCatalog = Self.decode("razors")
		async let logicSymbols: LogicSymbolCatalog = Self.decode("symbols")

		let results = try await (
			biases,
			concepts,
			fallacies,
			razors,
			logicSymbols
		)

		self.biases = results.0
		self.concepts = results.1
		self.fallacies = results.2
		self.razors = results.3
		self.logicSymbols = results.4

		isLoaded = true
	}

	nonisolated private static func decode<T: Decodable & Sendable>(
		_ name: String
	) throws -> T {
		guard let url = Bundle.main.url(
			forResource: name,
			withExtension: "json"
		) else {
			throw CocoaError(.fileNoSuchFile)
		}

		let data = try Data(contentsOf: url)
		return try JSONDecoder().decode(T.self, from: data)
	}
}
