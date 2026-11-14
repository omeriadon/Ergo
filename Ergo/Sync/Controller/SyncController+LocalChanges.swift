//
//  SyncController+LocalChanges.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import SwiftUI
#if os(iOS)
	import UIKit
#endif

extension SyncController {
	// MARK: - Local changes

	func record(_ boards: [Board], deleted: Set<Board.ID>) {
		guard isSignedIn else { return }

		// A viewer's device has nothing to push, not even a rebuilt placeholder. `deleted` still goes: it's leaving.
		let boards = boards.filter { boardStore.canEdit($0.id) }

		// Before anything is recorded: a link to a statement deleted here only counts as the board's while that statement lives
		let removed = removedRecords(from: boards)

		var changed = false
		for board in boards {
			if let fields = try? BoardRecord.fields(of: board) {
				changed = replica.recordLocal(kind: .board, id: BoardRecord.id(board.id), fields: fields) || changed
			}
			for statement in board.statements {
				guard let fields = try? StatementRecord.fields(of: statement, in: board.id) else { continue }
				changed = replica.recordLocal(kind: .statement, id: StatementRecord.id(statement.id), fields: fields) || changed
			}
			for link in board.links {
				changed = replica.recordLocal(kind: .link, id: LinkRecord.id(link.id), fields: LinkRecord.fields(of: link, in: board.id)) || changed
			}
			for source in board.sources {
				guard let fields = try? SourceRecord.fields(of: source, in: board.id) else { continue }
				changed = replica.recordLocal(kind: .source, id: SourceRecord.id(source.id), fields: fields) || changed
			}
		}
		for (kind, id) in removed {
			changed = replica.recordLocal(kind: kind, id: id, fields: [SyncFieldName.deleted: true]) || changed
		}
		// Only the board's tombstone: its statements and links are ignored with it, and the server prunes them
		for id in deleted {
			changed = replica.recordLocal(kind: .board, id: BoardRecord.id(id), fields: [SyncFieldName.deleted: true]) || changed
		}
		if changed {
			saveReplica()
			scheduleSync()
		}
	}

	/// Statements and links the replica has alive for these boards that the boards no longer have, because they were
	/// deleted here. Only ones this version can read, and never ones the replica ignores (their board or statement
	/// might just not have arrived), so it never deletes what it hasn't shown.
	private func removedRecords(from boards: [Board]) -> [(kind: SyncKind, id: String)] {
		let local = Dictionary(boards.map { (BoardRecord.id($0.id), $0) }) { first, _ in first }
		var removed: [(kind: SyncKind, id: String)] = []
		for record in replica.records.values where !record.isDeleted {
			guard let owner = record.owningBoard, let board = local[owner], !replica.isIgnored(record) else { continue }
			switch record.kind {
				case .statement:
					if StatementRecord.canRead(record), !board.statements.contains(where: { StatementRecord.id($0.id) == record.id }) {
						removed.append((.statement, record.id))
					}
				case .link:
					if LinkRecord.link(from: record) != nil, !board.links.contains(where: { LinkRecord.id($0.id) == record.id }) {
						removed.append((.link, record.id))
					}
				case .source:
					if SourceRecord.canRead(record), !board.sources.contains(where: { SourceRecord.id($0.id) == record.id }) {
						removed.append((.source, record.id))
					}
				default:
					break
			}
		}
		return removed
	}

	func recordScratchpads(_ scratchpads: [LogicScratchpad], deleted: Set<LogicScratchpad.ID>) {
		guard isSignedIn else { return }

		var changed = false
		for scratchpad in scratchpads {
			if let fields = try? ScratchpadRecord.fields(of: scratchpad) {
				changed = replica.recordLocal(kind: .scratchpad, id: ScratchpadRecord.id(scratchpad.id), fields: fields) || changed
			}
		}
		for id in deleted {
			changed = replica.recordLocal(kind: .scratchpad, id: ScratchpadRecord.id(id), fields: [SyncFieldName.deleted: true]) || changed
		}
		if changed {
			saveReplica()
			scheduleSync()
		}
	}

	func record(_ setting: SyncedSetting) {
		guard let value = setting.localValue else { return }
		if replica.recordLocal(kind: .setting, id: setting.rawValue, fields: [SyncFieldName.value: value]) {
			scheduleSync()
		}
	}

	func recordBookmarks() {
		let bookmarked = Set(Defaults[.bookmarks].map(\.id))
		var changed = false
		for id in bookmarked {
			changed = replica.recordLocal(kind: .bookmark, id: id, fields: [SyncFieldName.present: true]) || changed
		}

		// Only ones this catalog knows: the rest are another version's, never shown here, so never removed here
		let removed = replica.records.values.filter { record in
			record.kind == .bookmark
				&& record.fields[SyncFieldName.present]?.value == true
				&& !bookmarked.contains(record.id)
				&& catalog.index.resolve(record.id) != nil
		}
		for record in removed {
			changed = replica.recordLocal(kind: .bookmark, id: record.id, fields: [SyncFieldName.present: false]) || changed
		}
		if changed {
			scheduleSync()
		}
	}

	/// Everything as it is now, after signing in or anything missed while signed out.
	/// The replica only stamps what differs, so this costs a comparison per record.
	func recordAll() {
		for setting in SyncedSetting.allCases {
			// Left alone if it holds a value this version can't read, so it isn't overwritten with a local default
			if let synced = replica[.setting, setting.rawValue]?.fields[SyncFieldName.value], !setting.canDecode(synced.value) {
				continue
			}
			record(setting)
		}
		recordBookmarks()

		// Deleted here while signed out. Only boards this version could show, so it never deletes one it skipped.
		// Never a shared one: a board that failed to decode must not become a delete for everyone.
		let local = Set(boardStore.boards.map { BoardRecord.id($0.id) })
		let missing = replica.records.values.filter { record in
			record.kind == .board
				&& !record.isDeleted
				&& !local.contains(record.id)
				&& BoardRecord.canRead(record)
				&& !BoardShareRecords.isShared(record.id, in: replica)
		}
		record(boardStore.boards, deleted: Set(missing.compactMap { UUID(uuidString: $0.id) }))

		// The same for scratchpads
		let localScratchpads = Set(scratchpadStore.scratchpads.map { ScratchpadRecord.id($0.id) })
		let missingScratchpads = replica.records.values.filter { record in
			record.kind == .scratchpad
				&& !record.isDeleted
				&& !localScratchpads.contains(record.id)
				&& ScratchpadRecord.canRead(record)
		}
		recordScratchpads(scratchpadStore.scratchpads, deleted: Set(missingScratchpads.compactMap { UUID(uuidString: $0.id) }))
		saveReplica()
	}

	func saveReplica() {
		Defaults[.syncState] = replica

		let oversized = replica.oversized
		oversizedBoards = boardStore.boards
			.filter { board in
				oversized.contains(SyncRecord.Key(kind: .board, id: BoardRecord.id(board.id)))
					|| board.statements.contains { oversized.contains(SyncRecord.Key(kind: .statement, id: StatementRecord.id($0.id))) }
					|| board.sources.contains { oversized.contains(SyncRecord.Key(kind: .source, id: SourceRecord.id($0.id))) }
			}
			.map(\.title)

		let letters = LogicLetters.resolved(Defaults[.logicLetters])
		oversizedBoards += scratchpadStore.scratchpads
			.filter { oversized.contains(SyncRecord.Key(kind: .scratchpad, id: ScratchpadRecord.id($0.id))) }
			.map { $0.title(letters: letters) }
	}
}
