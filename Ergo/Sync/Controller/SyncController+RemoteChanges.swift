//
//  SyncController+RemoteChanges.swift
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
	// MARK: - Remote changes

	/// `pullComplete` is false while more is still coming. A statement a link joins can be missing only because it
	/// hasn't arrived yet, so links are only cleaned up once everything has.
	func write(_ applied: SyncApplied, pullComplete: Bool) {
		var affected: Set<Board.ID> = []
		var affectedScratchpads: Set<LogicScratchpad.ID> = []
		for record in applied.changed {
			switch record.kind {
				case .board, .share:
					if let id = UUID(uuidString: record.id) {
						affected.insert(id)
					}
				case .statement, .link, .source:
					if let id = record.owningBoard.flatMap(UUID.init(uuidString:)) {
						affected.insert(id)
					}
				case .scratchpad:
					if let id = UUID(uuidString: record.id) {
						affectedScratchpads.insert(id)
					}
				case .bookmark:
					BookmarkRecord.write(record, catalog: catalog.index)
				case .setting:
					if let setting = SyncedSetting(rawValue: record.id), let value = record.fields[SyncFieldName.value] {
						setting.write(value.value)
					}
				default:
					continue
			}
		}

		// First, so a copy of what lost an edit below knows whether this person can still edit that board
		let shares = BoardShareRecords.shares(in: replica)
		if shares != boardStore.shares {
			boardStore.shares = shares
		}

		analysis.refresh(from: replica)

		// Boards are built from the replica as a whole, so the order records arrived in doesn't matter
		let rebuilt = BoardRecord.rebuild(affected, from: replica, local: boardStore.boards)
		boardStore.applyRemote(rebuilt.boards, deleted: rebuilt.deleted)

		// Only a statement's content is worth a copy. Everything else is last writer wins.
		for field in applied.superseded(.statement, field: SyncFieldName.content) {
			guard
				let id = UUID(uuidString: field.id),
				let board = boardStore.boards.first(where: { $0.statement(id) != nil }),
				let copy = StatementRecord.copy(of: field.lost, beside: id, in: board)
			else {
				continue
			}
			boardStore.insertStatementCopy(copy, into: board.id)
		}

		let rebuiltScratchpads = ScratchpadRecord.rebuild(affectedScratchpads, from: replica, local: scratchpadStore.scratchpads)
		scratchpadStore.applyRemote(rebuiltScratchpads.scratchpads, deleted: rebuiltScratchpads.deleted)

		// A scratchpad's content is worth a copy too
		for field in applied.superseded(.scratchpad, field: SyncFieldName.content) {
			guard
				let id = UUID(uuidString: field.id),
				let original = scratchpadStore.scratchpads.first(where: { $0.id == id }),
				let copy = ScratchpadRecord.copy(of: field.lost, beside: original)
			else {
				continue
			}
			scratchpadStore.insertCopy(copy)
		}

		if pullComplete {
			deleteDanglingLinks()
		}
	}

	/// A link whose statement is gone on a board that isn't. Another device deleted the statement without its links,
	/// or drew one to it at the same moment. The replica ignores it, so this makes that permanent.
	private func deleteDanglingLinks() {
		func isGone(_ kind: SyncKind, _ id: String) -> Bool {
			replica[kind, id].map(\.isDeleted) ?? true
		}

		let dangling = replica.records.values.filter { record in
			guard record.kind == .link, !record.isDeleted, let board = record.owningBoard, let ends = record.joined else { return false }
			// A viewer's cleanup would only be refused, then found again after that sync, for ever
			guard UUID(uuidString: board).map(boardStore.canEdit) ?? true else { return false }
			return !isGone(.board, board) && (isGone(.statement, ends.premise) || isGone(.statement, ends.conclusion))
		}

		var changed = false
		for record in dangling {
			changed = replica.recordLocal(kind: .link, id: record.id, fields: [SyncFieldName.deleted: true]) || changed
		}
		if changed {
			saveReplica()
			scheduleSync()
		}
	}
}
