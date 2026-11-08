//
//  StatementRecord.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoProtocol
import Foundation

/// A `Statement` as a statement record's fields. `position` is its own field, so dragging a box never clashes with
/// typing in it. The English is its `content`, and `source` is the region it's in.
enum StatementRecord {
	/// Never rename a property: it's on the server, and other devices decode it
	struct Content: Codable, Hashable {
		var english: String

		init(_ statement: Statement) {
			english = statement.english
		}
	}

	static func id(_ id: Statement.ID) -> String {
		id.uuidString
	}

	// MARK: - Local → record

	/// Every field but `deleted`, which is only ever sent when deleting
	static func fields(of statement: Statement, in board: Board.ID) throws -> [String: JSONValue] {
		try [
			SyncFieldName.board: .string(BoardRecord.id(board)),
			SyncFieldName.position: SyncCoding.value(statement.position),
			SyncFieldName.content: SyncCoding.value(Content(statement)),
			SyncFieldName.source: statement.source.map { .string(SourceRecord.id($0)) } ?? .null,
		]
	}

	// MARK: - Record → local

	/// Whether this version can show the statement, so one it can't is never deleted from here
	static func canRead(_ record: SyncRecord) -> Bool {
		statement(from: record, local: nil) != nil
	}

	/// The statement a record describes, built on `local` so a field the record lacks keeps its value here.
	/// Nil if a value fails to decode, or there's no content to show: then nothing local is touched.
	static func statement(from record: SyncRecord, local: Statement?) -> Statement? {
		guard let id = UUID(uuidString: record.id) else { return nil }
		var statement = local ?? Statement(id: id)

		if let content = record.fields[SyncFieldName.content] {
			guard let content = try? SyncCoding.decode(Content.self, from: content.value) else { return nil }
			statement.apply(content)
		} else if local == nil {
			return nil
		}

		if let position = record.fields[SyncFieldName.position] {
			guard let position = try? SyncCoding.decode(CanvasPoint.self, from: position.value) else { return nil }
			statement.position = position
		}

		if let source = record.fields[SyncFieldName.source] {
			if case let .string(id) = source.value {
				statement.source = UUID(uuidString: id)
			} else {
				statement.source = nil
			}
		}
		return statement
	}

	/// What lost a simultaneous edit, as a new statement on the same board, below the one that won.
	static func copy(of lost: SyncField, beside original: Statement.ID, in board: Board) -> Statement? {
		guard let content = try? SyncCoding.decode(Content.self, from: lost.value) else { return nil }
		var copy = Statement(position: CanvasLayout.place(newNodeNear: original, in: board.map, side: .below))
		copy.apply(content)
		return copy
	}
}

private extension Statement {
	mutating func apply(_ content: StatementRecord.Content) {
		english = content.english
	}
}
