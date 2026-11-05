//
//  PageRecord.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

/// A `LogicPage` as a page record's fields. English and logic travel together in `content`, since one follows the
/// other; each descriptor is its own field, so naming different letters on two devices keeps both.
/// `modified` isn't a field: it's the record's newest stamp, so every device sorts pages the same way.
enum PageRecord {
	/// Never rename a property: it's on the server, and other devices decode it
	struct Content: Codable, Hashable {
		var english: String
		var logic: [LogicKeyboardEntry]
		var source: LogicPage.Source
		var translation: Translation?

		init(_ page: LogicPage) {
			english = page.english
			logic = page.logic
			source = page.source
			translation = page.translation
		}
	}

	static func id(_ id: LogicPage.ID) -> String {
		id.uuidString
	}

	// MARK: - Local → record

	/// Every field but `deleted`, which is only ever sent when deleting
	static func fields(of page: LogicPage) throws -> [String: JSONValue] {
		var fields: [String: JSONValue] = try [
			SyncFieldName.created: SyncCoding.value(page.created),
			SyncFieldName.content: SyncCoding.value(Content(page)),
		]
		for slot in 0 ..< SyncFieldName.descriptorSlots {
			fields[SyncFieldName.descriptor(slot)] = .string(page.descriptors.indices.contains(slot) ? page.descriptors[slot] : "")
		}
		return fields
	}

	// MARK: - Record → local

	/// The page a record describes, built on `local` so a field the record lacks keeps its value here.
	/// Nil if any value fails to decode, or there's no content to show: then nothing local is touched.
	static func page(from record: SyncRecord, local: LogicPage?) -> LogicPage? {
		guard let id = UUID(uuidString: record.id) else { return nil }
		var page = local ?? LogicPage(id: id)

		if let content = record.fields[SyncFieldName.content] {
			guard let content = try? SyncCoding.decode(Content.self, from: content.value) else { return nil }
			page.apply(content)
		} else if local == nil {
			return nil
		}

		if let created = record.fields[SyncFieldName.created] {
			guard let created = try? SyncCoding.decode(Date.self, from: created.value) else { return nil }
			page.created = created
		}

		var descriptors = page.descriptors
		for slot in 0 ..< SyncFieldName.descriptorSlots {
			guard let field = record.fields[SyncFieldName.descriptor(slot)] else { continue }
			guard case let .string(descriptor) = field.value else { return nil }
			while descriptors.count <= slot {
				descriptors.append("")
			}
			descriptors[slot] = descriptor
		}
		page.descriptors = descriptors

		if let newest = record.newestStamp {
			page.modified = newest.date
		}
		return page
	}

	/// What lost a simultaneous edit, as a new page next to the one that won. It keeps that page's descriptors,
	/// which is what the lost English and logic were written against.
	static func copy(of lost: SyncField, descriptors: [String], created: Date) -> LogicPage? {
		guard let content = try? SyncCoding.decode(Content.self, from: lost.value) else { return nil }
		var page = LogicPage()
		page.apply(content)
		page.descriptors = descriptors
		page.created = created
		page.modified = lost.stamp.date
		return page
	}
}

private extension LogicPage {
	mutating func apply(_ content: PageRecord.Content) {
		english = content.english
		logic = content.logic
		source = content.source
		translation = content.translation
	}
}
