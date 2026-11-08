// Models for the eight bundled JSON catalogs.

import Defaults
import Foundation

nonisolated struct Example: Codable, Sendable {
	let text: String
	let note: String?

	private enum CodingKeys: String, CodingKey {
		case text
		case note
	}

	nonisolated var entityText: String {
		guard let note, !note.isEmpty else {
			return text
		}

		return "\(text) (\(note))"
	}
}

nonisolated struct CatalogLink: Codable, Sendable {
	let target: CatalogReference
	let note: String

	private enum CodingKeys: String, CodingKey {
		case targetID
		case note
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let targetID = try container.decode(String.self, forKey: .targetID)
		target = try CatalogReference(id: targetID, from: decoder)
		note = try container.decode(String.self, forKey: .note)
	}

	func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(target.id, forKey: .targetID)
		try container.encode(note, forKey: .note)
	}

	nonisolated var entityText: String {
		"\(target.name): \(note)"
	}
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

	nonisolated init(id: String, from decoder: any Decoder) throws {
		guard let index = decoder.userInfo[.catalogIndex] as? CatalogIndex else {
			throw CatalogIndexError.missingID(id)
		}

		self = try index.reference(for: id)
	}

	init(from decoder: any Decoder) throws {
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

	func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(name, forKey: .name)
		try container.encode(category, forKey: .category)
	}

	var route: LibraryRoute {
		.detail(category: category, id: id)
	}
}
