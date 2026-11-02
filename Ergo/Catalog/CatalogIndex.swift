//
//  CatalogIndex.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Foundation

enum CatalogIndexError: Error {
	case duplicateID(String)
	case emptyID
	case missingID(String)
	case invalidKeyFigure(String)
}

nonisolated struct CatalogIndex: Sendable {
	private var entries: [String: CatalogReference] = [:]

	mutating func register<T>(
		_ items: [T],
		category: LibraryContent,
		id: KeyPath<T, String>,
		name: KeyPath<T, String>
	) throws {
		for item in items {
			let identifier = item[keyPath: id]

			guard !identifier.isEmpty else {
				throw CatalogIndexError.emptyID
			}

			guard entries[identifier] == nil else {
				throw CatalogIndexError.duplicateID(identifier)
			}

			entries[identifier] = CatalogReference(
				id: identifier,
				name: item[keyPath: name],
				category: category
			)
		}
	}

	func resolve(_ id: String) -> CatalogReference? {
		entries[id]
	}

	func reference(for id: String) throws -> CatalogReference {
		guard let reference = entries[id] else {
			throw CatalogIndexError.missingID(id)
		}

		return reference
	}
}

extension CodingUserInfoKey {
	nonisolated static let catalogIndex = CodingUserInfoKey(rawValue: "catalogIndex")!
}

extension CatalogReference {
	nonisolated init(id: String, from decoder: Decoder) throws {
		guard let index = decoder.userInfo[.catalogIndex] as? CatalogIndex else {
			throw CatalogIndexError.missingID(id)
		}

		self = try index.reference(for: id)
	}
}
