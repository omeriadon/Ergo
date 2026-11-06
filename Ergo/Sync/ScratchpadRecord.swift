//
//  ScratchpadRecord.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

/// A `LogicScratchpad` as a scratchpad record's fields: `created`, one field per descriptor, so naming different
/// letters on two devices keeps both, and `content`. English and logic travel together in `content`, since one
/// follows the other. A scratchpad has no child records.
///
/// `modified` isn't a field: it's the record's newest stamp, so every device sorts scratchpads the same way.
enum ScratchpadRecord {
	/// Never rename a property: it's on the server, and other devices decode it
	struct Content: Codable, Hashable {
		var english: String
		var logic: [LogicKeyboardEntry]
		var source: LogicScratchpad.Source
		var translation: Translation?

		init(_ scratchpad: LogicScratchpad) {
			english = scratchpad.english
			logic = scratchpad.logic
			source = scratchpad.source
			translation = scratchpad.translation
		}
	}

	static func id(_ id: LogicScratchpad.ID) -> String {
		id.uuidString
	}

	// MARK: - Local → record

	/// Every field but `deleted`, which is only ever sent when deleting
	static func fields(of scratchpad: LogicScratchpad) throws -> [String: JSONValue] {
		var fields: [String: JSONValue] = try [
			SyncFieldName.created: SyncCoding.value(scratchpad.created),
			SyncFieldName.content: SyncCoding.value(Content(scratchpad)),
		]
		for slot in 0 ..< SyncFieldName.descriptorSlots {
			fields[SyncFieldName.descriptor(slot)] = .string(scratchpad.descriptors.indices.contains(slot) ? scratchpad.descriptors[slot] : "")
		}
		return fields
	}

	// MARK: - Record → local

	/// Whether this version can show the scratchpad, so one it can't (from a newer app, or damaged) is never deleted from here
	static func canRead(_ record: SyncRecord) -> Bool {
		guard UUID(uuidString: record.id) != nil else { return false }
		if let created = record.fields[SyncFieldName.created], (try? SyncCoding.decode(Date.self, from: created.value)) == nil {
			return false
		}
		if let content = record.fields[SyncFieldName.content], (try? SyncCoding.decode(Content.self, from: content.value)) == nil {
			return false
		}
		for slot in 0 ..< SyncFieldName.descriptorSlots {
			guard let field = record.fields[SyncFieldName.descriptor(slot)] else { continue }
			guard case .string = field.value else { return false }
		}
		return true
	}

	/// Scratchpads the replica has changed, and the ones it deleted
	struct Rebuilt {
		var scratchpads: [LogicScratchpad] = []
		var deleted: Set<LogicScratchpad.ID> = []
	}

	/// The scratchpads with these ids as the replica now has them, built on `local` so what the replica lacks or can't
	/// read keeps its value here. The replica holds the merged state including local edits, so this is the local state
	/// plus what other devices changed.
	static func rebuild(_ ids: Set<LogicScratchpad.ID>, from replica: SyncReplica, local: [LogicScratchpad]) -> Rebuilt {
		var rebuilt = Rebuilt()
		for scratchpadID in ids {
			guard let record = replica[.scratchpad, id(scratchpadID)] else { continue }
			if record.isDeleted {
				rebuilt.deleted.insert(scratchpadID)
				continue
			}
			if let scratchpad = scratchpad(from: record, local: local.first { $0.id == scratchpadID }) {
				rebuilt.scratchpads.append(scratchpad)
			}
		}
		return rebuilt
	}

	/// Nil if a value fails to decode: then nothing local is touched
	private static func scratchpad(from record: SyncRecord, local: LogicScratchpad?) -> LogicScratchpad? {
		guard let scratchpadID = UUID(uuidString: record.id), canRead(record) else { return nil }
		var scratchpad = local ?? LogicScratchpad(id: scratchpadID)

		if let created = record.fields[SyncFieldName.created], let date = try? SyncCoding.decode(Date.self, from: created.value) {
			scratchpad.created = date
		}
		for slot in 0 ..< SyncFieldName.descriptorSlots {
			guard case let .string(descriptor)? = record.fields[SyncFieldName.descriptor(slot)]?.value else { continue }
			while scratchpad.descriptors.count <= slot {
				scratchpad.descriptors.append("")
			}
			scratchpad.descriptors[slot] = descriptor
		}
		if let content = record.fields[SyncFieldName.content], let content = try? SyncCoding.decode(Content.self, from: content.value) {
			scratchpad.apply(content)
		}
		if let newest = record.newestStamp {
			scratchpad.modified = newest.date
		}
		return scratchpad
	}

	/// What lost a simultaneous edit, as a new scratchpad beside the one that won. It keeps the original's
	/// descriptors, so the lost logic still means what it did.
	static func copy(of lost: SyncField, beside original: LogicScratchpad) -> LogicScratchpad? {
		guard let content = try? SyncCoding.decode(Content.self, from: lost.value) else { return nil }
		var copy = LogicScratchpad()
		copy.descriptors = original.descriptors
		copy.apply(content)
		return copy
	}
}

private extension LogicScratchpad {
	mutating func apply(_ content: ScratchpadRecord.Content) {
		english = content.english
		logic = content.logic
		source = content.source
		translation = content.translation
	}
}
