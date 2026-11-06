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

/// A `LogicPage` as a page record's fields: `created` and one field per descriptor, so naming different letters on
/// two devices keeps both. Statements and links are records of their own (`StatementRecord`, `LinkRecord`), so typing
/// in one box, dragging another and drawing an arrow never clash.
///
/// `modified` isn't a field: it's the newest stamp in the page's records, so every device sorts pages the same way.
enum PageRecord {
	static func id(_ id: LogicPage.ID) -> String {
		id.uuidString
	}

	// MARK: - Local → record

	/// Every field but `deleted`, which is only ever sent when deleting
	static func fields(of page: LogicPage) throws -> [String: JSONValue] {
		var fields: [String: JSONValue] = try [
			SyncFieldName.created: SyncCoding.value(page.created),
		]
		for slot in 0 ..< SyncFieldName.descriptorSlots {
			fields[SyncFieldName.descriptor(slot)] = .string(page.descriptors.indices.contains(slot) ? page.descriptors[slot] : "")
		}
		return fields
	}

	// MARK: - Record → local

	/// Whether this version can show the page, so one it can't (from a newer app, or damaged) is never deleted from here
	static func canRead(_ record: SyncRecord) -> Bool {
		guard UUID(uuidString: record.id) != nil else { return false }
		if let created = record.fields[SyncFieldName.created], (try? SyncCoding.decode(Date.self, from: created.value)) == nil {
			return false
		}
		for slot in 0 ..< SyncFieldName.descriptorSlots {
			guard let field = record.fields[SyncFieldName.descriptor(slot)] else { continue }
			guard case .string = field.value else { return false }
		}
		return true
	}

	/// Pages the replica has changed, and the ones it deleted
	struct Rebuilt {
		var pages: [LogicPage] = []
		var deleted: Set<LogicPage.ID> = []
	}

	/// The pages with these ids as the replica now has them, built on `local` so what the replica lacks or can't read
	/// keeps its value here. The replica holds the merged state including local edits, so this is the local state plus
	/// what other devices changed.
	///
	/// Statements and links the replica reports as ignored (their page is deleted or missing, or a link's statement is)
	/// are left out, and so are links that would repeat or loop an arrow, in the order of their ids so every device drops the same one.
	/// A page without statements gets an empty one, since a page is never without.
	static func rebuild(_ ids: Set<LogicPage.ID>, from replica: SyncReplica, local: [LogicPage]) -> Rebuilt {
		let wanted = Set(ids.map { id($0) })
		var statements: [String: [SyncRecord]] = [:]
		var links: [String: [SyncRecord]] = [:]
		for record in replica.records.values {
			guard let page = record.owningPage, wanted.contains(page) else { continue }
			switch record.kind {
				case .statement:
					statements[page, default: []].append(record)
				case .link:
					links[page, default: []].append(record)
				default:
					break
			}
		}

		var rebuilt = Rebuilt()
		for pageID in ids {
			guard let record = replica[.page, id(pageID)] else { continue }
			if record.isDeleted {
				rebuilt.deleted.insert(pageID)
				continue
			}
			let records = Records(page: record, statements: statements[id(pageID)] ?? [], links: links[id(pageID)] ?? [])
			if let page = page(from: records, replica: replica, local: local.first { $0.id == pageID }) {
				rebuilt.pages.append(page)
			}
		}
		return rebuilt
	}

	private struct Records {
		var page: SyncRecord
		var statements: [SyncRecord]
		var links: [SyncRecord]

		/// Deleted ones count too: deleting is a change
		var newestStamp: SyncStamp? {
			([page] + statements + links).compactMap(\.newestStamp).max()
		}
	}

	/// Nil if the page's own fields fail to decode: then nothing local is touched
	private static func page(from records: Records, replica: SyncReplica, local: LogicPage?) -> LogicPage? {
		guard let pageID = UUID(uuidString: records.page.id), canRead(records.page) else { return nil }
		var page = local ?? LogicPage(id: pageID)

		if let created = records.page.fields[SyncFieldName.created], let date = try? SyncCoding.decode(Date.self, from: created.value) {
			page.created = date
		}
		for slot in 0 ..< SyncFieldName.descriptorSlots {
			guard case let .string(descriptor)? = records.page.fields[SyncFieldName.descriptor(slot)]?.value else { continue }
			while page.descriptors.count <= slot {
				page.descriptors.append("")
			}
			page.descriptors[slot] = descriptor
		}
		if let newest = records.newestStamp {
			page.modified = newest.date
		}

		page.statements = statements(of: records.statements, replica: replica, local: local?.statements ?? [])
		page.links = links(of: records.links, replica: replica, local: local?.links ?? [], among: page.statements)
		return page
	}

	/// What the replica has, in this device's order, then new ones from the top left
	private static func statements(of records: [SyncRecord], replica: SyncReplica, local: [Statement]) -> [Statement] {
		let localByID = Dictionary(local.map { ($0.id, $0) }) { first, _ in first }
		var remote: [Statement.ID: Statement] = [:]
		for record in records where !record.isDeleted && !replica.isIgnored(record) {
			if let statement = StatementRecord.statement(from: record, local: UUID(uuidString: record.id).flatMap { localByID[$0] }) {
				remote[statement.id] = statement
			}
		}

		var statements: [Statement] = []
		for statement in local {
			if let updated = remote.removeValue(forKey: statement.id) {
				statements.append(updated)
			} else if replica[.statement, StatementRecord.id(statement.id)] == nil, !statement.isEmpty {
				// Not recorded yet
				statements.append(statement)
			}
		}
		statements += remote.values.sorted { a, b in
			(a.position.y, a.position.x, a.id.uuidString) < (b.position.y, b.position.x, b.id.uuidString)
		}

		if statements.isEmpty {
			// An empty one this device already made, so rebuilding doesn't keep making new ones
			let placeholder = local.first { $0.isEmpty && replica[.statement, StatementRecord.id($0.id)] == nil }
			statements = [placeholder ?? Statement()]
		}
		return statements
	}

	/// Links the replica doesn't have yet (this device's, before its first pull has finished) stay
	private static func links(of records: [SyncRecord], replica: SyncReplica, local: [Link], among statements: [Statement]) -> [Link] {
		let ids = Set(statements.map(\.id))
		var map = ArgumentMap<Statement, Link>(statements: statements)
		let remote = records
			.filter { !$0.isDeleted && !replica.isIgnored($0) }
			.compactMap { LinkRecord.link(from: $0) }
		let unrecorded = local.filter { replica[.link, LinkRecord.id($0.id)] == nil }
		let candidates = (remote + unrecorded)
			.filter { ids.contains($0.premise) && ids.contains($0.conclusion) }
			.sorted { $0.id.uuidString < $1.id.uuidString }
		for link in candidates where ArgumentMapValidator.problem(adding: link, to: map) == nil {
			map.links.append(link)
		}
		return map.links
	}
}
