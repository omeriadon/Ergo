//
//  BoardStore.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import SwiftUI

/// Every board, and which one the Board tab is showing. Shared so the boards list
/// and the editor edit the same board.
///
/// Statements, links and sources are edited on the current board through the methods under "statements", "links" and "sources". Each
/// one bumps `modified` and goes through `current`, so it's saved after a pause and reported to sync with the board.
@MainActor
@Observable
final class BoardStore {
	// MARK: - boards

	var boards: [Board]

	/// Newest first
	var sortedBoards: [Board] {
		boards.sorted { $0.modified > $1.modified }
	}

	// MARK: - current

	var currentID: Board.ID? {
		didSet {
			Defaults[.currentBoardID] = currentID
		}
	}

	/// Stays out of the list until something's written on it
	var draft = Board()

	var current: Board {
		get {
			boards.first { $0.id == currentID } ?? draft
		}
		set {
			// Every edit comes through here, so this is the one place a viewer is stopped
			guard canEdit(newValue.id) else { return }

			var board = newValue
			board.modified = .now

			if let index = boards.firstIndex(where: { $0.id == board.id }) {
				boards[index] = board
				changedIDs.insert(board.id)
			} else if board.isEmpty {
				draft = board
			} else {
				boards.append(board)
				changedIDs.insert(board.id)
				currentID = board.id
			}

			scheduleSave()
		}
	}

	/// Goes up when another device changes the open board, so the editor can drop a selection that no longer fits
	var remoteEdits = 0

	@ObservationIgnored
	var saveTask: Task<Void, Never>?

	init() {
		boards = Defaults[.boards]
		currentID = Defaults[.currentBoardID]
	}

	// MARK: - sharing

	/// Who's on each shared board, read from the replica's `share` records by `SyncController` on launch and after every
	/// sync. Not on `Board`, so it can't go stale.
	var shares: [Board.ID: BoardShare] = [:]

	/// True for a board that isn't shared, or one this person's role can edit
	func canEdit(_ id: Board.ID) -> Bool {
		shares[id]?.role.canEdit ?? true
	}

	// MARK: - newBoard

	func newBoard() {
		discardCurrentIfEmpty()
		draft = Board()
		currentID = nil
	}

	// MARK: - open

	func open(_ id: Board.ID) {
		guard id != currentID else { return }
		discardCurrentIfEmpty()
		currentID = id
	}

	// MARK: - delete

	func delete(_ ids: Set<Board.ID>) {
		boards.removeAll { ids.contains($0.id) }
		deletedIDs.formUnion(ids)
		if let currentID, ids.contains(currentID) {
			newBoard()
		}
		save()
	}

	// MARK: - rename

	/// An empty name goes back to titling the board from what's written on it
	func rename(_ id: Board.ID, to name: String) {
		guard canEdit(id), let index = boards.firstIndex(where: { $0.id == id }) else { return }
		boards[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
		boards[index].modified = .now
		changedIDs.insert(id)
		scheduleSave()
	}

	// MARK: - save

	/// What changed since the last save, for sync
	@ObservationIgnored
	var changedIDs: Set<Board.ID> = []

	@ObservationIgnored
	var deletedIDs: Set<Board.ID> = []

	/// Hears every save with the boards that changed and the ones deleted. Remote changes aren't passed back.
	@ObservationIgnored
	var didSave: ((_ changed: [Board], _ deleted: Set<Board.ID>) -> Void)?

	/// Typing changes the board on every keystroke, so writes wait for a pause
	func scheduleSave() {
		saveTask?.cancel()
		saveTask = Task {
			try? await Task.sleep(for: .seconds(1))
			guard !Task.isCancelled else { return }
			save()
		}
	}

	func save() {
		saveTask?.cancel()
		Defaults[.boards] = boards

		let changed = boards.filter { changedIDs.contains($0.id) }
		let deleted = deletedIDs
		changedIDs = []
		deletedIDs = []
		if !changed.isEmpty || !deleted.isEmpty {
			didSave?(changed, deleted)
		}
	}

	func discardCurrentIfEmpty() {
		// A shared board's tombstone would be a leave, or a delete for everyone
		guard let currentID, current.isEmpty, shares[currentID] == nil else { return }
		boards.removeAll { $0.id == currentID }
		deletedIDs.insert(currentID)
		save()
	}

	// MARK: - sync

	/// Writes what other devices changed. Keeps their `modified`, and doesn't report it back as a local change.
	func applyRemote(_ remote: [Board], deleted: Set<Board.ID>) {
		guard !remote.isEmpty || !deleted.isEmpty else { return }

		for board in remote {
			if let index = boards.firstIndex(where: { $0.id == board.id }) {
				// Only the stamps moving isn't an edit
				var old = boards[index]
				old.modified = board.modified
				if old != board, board.id == currentID {
					remoteEdits += 1
				}
				boards[index] = board
			} else {
				boards.append(board)
			}
		}
		boards.removeAll { deleted.contains($0.id) }

		// Deleted on another device, so it goes the same way as deleting it here
		if let currentID, deleted.contains(currentID) {
			draft = Board()
			self.currentID = nil
		}

		Defaults[.boards] = boards
	}

	/// A statement holding what lost a simultaneous edit on another device, on the board it was edited on.
	/// It syncs like any new statement, and isn't held to the statement limit, since nothing may be lost.
	func insertStatementCopy(_ statement: Statement, into boardID: Board.ID) {
		guard canEdit(boardID), let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
		boards[index].statements.append(statement)
		boards[index].modified = .now
		changedIDs.insert(boardID)
		save()
	}
}
