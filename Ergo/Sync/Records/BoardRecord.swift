//
//  BoardRecord.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

/// A `Board` as a board record's fields: just `created`. Statements, links and sources are records of their own
/// (`StatementRecord`, `LinkRecord`, `SourceRecord`), so typing in one box, dragging another and drawing an arrow never clash.
///
/// `modified` isn't a field: it's the newest stamp in the board's records, so every device sorts boards the same way.
enum BoardRecord {
	static func id(_ id: Board.ID) -> String {
		id.uuidString
	}

	// MARK: - Local → record

	/// Every field but `deleted`, which is only ever sent when deleting
	static func fields(of board: Board) throws -> [String: JSONValue] {
		try [
			SyncFieldName.created: SyncCoding.value(board.created),
			SyncFieldName.name: .string(board.name),
		]
	}

	// MARK: - Record → local

	/// Whether this version can show the board, so one it can't (from a newer app, or damaged) is never deleted from here
	static func canRead(_ record: SyncRecord) -> Bool {
		guard UUID(uuidString: record.id) != nil else { return false }
		if let created = record.fields[SyncFieldName.created], (try? SyncCoding.decode(Date.self, from: created.value)) == nil {
			return false
		}
		if let name = record.fields[SyncFieldName.name] {
			guard case .string = name.value else { return false }
		}
		return true
	}

	/// Boards the replica has changed, and the ones it deleted
	struct Rebuilt {
		var boards: [Board] = []
		var deleted: Set<Board.ID> = []
	}

	/// The boards with these ids as the replica now has them, built on `local` so what the replica lacks or can't read
	/// keeps its value here. The replica holds the merged state including local edits, so this is the local state plus
	/// what other devices changed.
	///
	/// Statements and links the replica reports as ignored (their board is deleted or missing, or a link's statement is)
	/// are left out, and so are links that would repeat or loop an arrow, in the order of their ids so every device drops the same one.
	/// A board without statements gets an empty one, since a board is never without.
	static func rebuild(_ ids: Set<Board.ID>, from replica: SyncReplica, local: [Board]) -> Rebuilt {
		let wanted = Set(ids.map { id($0) })
		var statements: [String: [SyncRecord]] = [:]
		var links: [String: [SyncRecord]] = [:]
		var sources: [String: [SyncRecord]] = [:]
		for record in replica.records.values {
			guard let board = record.owningBoard, wanted.contains(board) else { continue }
			switch record.kind {
				case .statement:
					statements[board, default: []].append(record)
				case .link:
					links[board, default: []].append(record)
				case .source:
					sources[board, default: []].append(record)
				default:
					break
			}
		}

		var rebuilt = Rebuilt()
		for boardID in ids {
			guard let record = replica[.board, id(boardID)] else { continue }
			if record.isDeleted {
				rebuilt.deleted.insert(boardID)
				continue
			}
			let records = Records(board: record, statements: statements[id(boardID)] ?? [], links: links[id(boardID)] ?? [], sources: sources[id(boardID)] ?? [])
			if let board = board(from: records, replica: replica, local: local.first { $0.id == boardID }) {
				rebuilt.boards.append(board)
			}
		}
		return rebuilt
	}

	private struct Records {
		var board: SyncRecord
		var statements: [SyncRecord]
		var links: [SyncRecord]
		var sources: [SyncRecord]

		/// Deleted ones count too: deleting is a change
		var newestStamp: SyncStamp? {
			([board] + statements + links + sources).compactMap(\.newestStamp).max()
		}
	}

	/// Nil if the board's own fields fail to decode: then nothing local is touched
	private static func board(from records: Records, replica: SyncReplica, local: Board?) -> Board? {
		guard let boardID = UUID(uuidString: records.board.id), canRead(records.board) else { return nil }
		var board = local ?? Board(id: boardID)

		if let created = records.board.fields[SyncFieldName.created], let date = try? SyncCoding.decode(Date.self, from: created.value) {
			board.created = date
		}
		if case let .string(name)? = records.board.fields[SyncFieldName.name]?.value {
			board.name = name
		}
		if let newest = records.newestStamp {
			board.modified = newest.date
		}

		board.sources = sources(of: records.sources, replica: replica, local: local?.sources ?? [])
		board.statements = statements(of: records.statements, replica: replica, local: local?.statements ?? [], hasSources: !board.sources.isEmpty)
		board.links = links(of: records.links, replica: replica, local: local?.links ?? [], among: board.statements)
		return board
	}

	/// What the replica has, in this device's order, then new ones from the top left
	private static func statements(of records: [SyncRecord], replica: SyncReplica, local: [Statement], hasSources: Bool) -> [Statement] {
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

		if statements.isEmpty, !hasSources {
			// An empty one this device already made, so rebuilding doesn't keep making new ones
			let placeholder = local.first { $0.isEmpty && replica[.statement, StatementRecord.id($0.id)] == nil }
			statements = [placeholder ?? Statement()]
		}
		return statements
	}

	/// What the replica has, in this device's order, then new ones from the top left
	private static func sources(of records: [SyncRecord], replica: SyncReplica, local: [BoardSource]) -> [BoardSource] {
		let localByID = Dictionary(local.map { ($0.id, $0) }) { first, _ in first }
		var remote: [BoardSource.ID: BoardSource] = [:]
		for record in records where !record.isDeleted && !replica.isIgnored(record) {
			if let source = SourceRecord.source(from: record, local: UUID(uuidString: record.id).flatMap { localByID[$0] }) {
				remote[source.id] = source
			}
		}

		var sources: [BoardSource] = []
		for source in local {
			if let updated = remote.removeValue(forKey: source.id) {
				sources.append(updated)
			} else if replica[.source, SourceRecord.id(source.id)] == nil {
				// Not recorded yet
				sources.append(source)
			}
		}
		return sources + remote.values.sorted { a, b in
			(a.position.y, a.position.x, a.id.uuidString) < (b.position.y, b.position.x, b.id.uuidString)
		}
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
