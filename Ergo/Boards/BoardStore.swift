//
//  BoardStore.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import ErgoTranslation
import SwiftUI

/// Every board, and which one the Board tab is showing. Shared so the boards list
/// and the editor edit the same board.
///
/// Statements and links are edited on the current board through the methods under "statements" and "links". Each
/// one bumps `modified` and goes through `current`, so it's saved after a pause and reported to sync with the board.
@MainActor
@Observable
final class BoardStore {
	// MARK: - boards

	private(set) var boards: [Board]

	/// Newest first
	var sortedBoards: [Board] {
		boards.sorted { $0.modified > $1.modified }
	}

	// MARK: - current

	private(set) var currentID: Board.ID? {
		didSet {
			Defaults[.currentBoardID] = currentID
		}
	}

	/// Stays out of the list until something's written on it
	private var draft = Board()

	var current: Board {
		get {
			boards.first { $0.id == currentID } ?? draft
		}
		set {
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
	private(set) var remoteEdits = 0

	@ObservationIgnored
	private var saveTask: Task<Void, Never>?

	init() {
		boards = Defaults[.boards]
		currentID = Defaults[.currentBoardID]
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

	// MARK: - statements

	/// The statement on the current board, nil once it's gone (deleted here or on another device)
	func statement(_ id: Statement.ID) -> Statement? {
		current.statement(id)
	}

	/// Reads and writes one statement of the current board. If the statement goes away while a view still holds the
	/// binding, reads give the last value it had and writes are dropped, so a view never crashes on a deleted box.
	func binding(for id: Statement.ID) -> Binding<Statement>? {
		guard let last = statement(id) else { return nil }
		return Binding(
			get: { [self] in statement(id) ?? last },
			set: { [self] in updateStatement($0) }
		)
	}

	/// Adds an empty statement with its centre at `position`, for the canvas dropping one where the person is looking.
	/// Nil when the board is full (`ArgumentMapValidator.defaultMaximumStatements`).
	@discardableResult
	func addStatement(at position: CanvasPoint) -> Statement.ID? {
		var board = current
		guard board.statements.count < ArgumentMapValidator.defaultMaximumStatements else { return nil }

		let statement = Statement(position: position)
		board.statements.append(statement)
		current = board
		return statement.id
	}

	/// Replaces the statement with the same id. Typing goes through here, so one that changes nothing is skipped.
	func updateStatement(_ statement: Statement) {
		var board = current
		guard let index = board.statements.firstIndex(where: { $0.id == statement.id }), board.statements[index] != statement else { return }
		board.statements[index] = statement
		current = board
	}

	/// Sets the centre of the box. Call it when a drag ends: sync writes the position as its own field, and every call restarts the save timer.
	func moveStatement(id: Statement.ID, to position: CanvasPoint) {
		var board = current
		guard let index = board.statements.firstIndex(where: { $0.id == id }), board.statements[index].position != position else { return }
		board.statements[index].position = position
		current = board
	}

	/// Deletes the statement and the links that touch it. The last statement is replaced with an empty one in the same
	/// place, since a board is never without one.
	func deleteStatement(id: Statement.ID) {
		var board = current
		guard let index = board.statements.firstIndex(where: { $0.id == id }) else { return }
		let position = board.statements[index].position
		board.statements.remove(at: index)
		board.links.removeAll { $0.premise == id || $0.conclusion == id }
		if board.statements.isEmpty {
			board.statements = [Statement(position: position)]
		}
		current = board
	}

	// MARK: - links

	/// Draws an arrow from `premise` to `conclusion`. Nothing is added when it would be wrong (the same arrow twice,
	/// a statement to itself, a loop), and the reason comes back.
	@discardableResult
	func link(premise: Statement.ID, conclusion: Statement.ID) -> ArgumentMapProblem? {
		var board = current
		let link = Link(premise: premise, conclusion: conclusion)
		if let problem = ArgumentMapValidator.problem(adding: link, to: board.map) {
			return problem
		}
		board.links.append(link)
		current = board
		return nil
	}

	func unlink(id: Link.ID) {
		var board = current
		guard board.links.contains(where: { $0.id == id }) else { return }
		board.links.removeAll { $0.id == id }
		current = board
	}

	// MARK: - arranging

	/// Lays every statement out again (`CanvasLayout.arranged`)
	func arrange() {
		var board = current
		let map = CanvasLayout.arranged(board.map)
		guard map.statements != board.statements else { return }
		board.map = map
		current = board
	}

	// MARK: - breaking down

	/// Opens a new board holding a server breakdown: a statement per premise and one for the conclusion, every premise linked
	/// to it (`ArgumentBreakdown.applied`). The breakdown's claims are dropped, since a board holds English only.
	/// Statements past the limit are left out.
	func newBoard(from breakdown: ArgumentBreakdown) {
		newBoard()

		var board = current
		board.map = breakdown.applied(to: board.map, replacing: true).map
		current = board
	}

	// MARK: - save

	/// What changed since the last save, for sync
	@ObservationIgnored
	private var changedIDs: Set<Board.ID> = []

	@ObservationIgnored
	private var deletedIDs: Set<Board.ID> = []

	/// Hears every save with the boards that changed and the ones deleted. Remote changes aren't passed back.
	@ObservationIgnored
	var didSave: ((_ changed: [Board], _ deleted: Set<Board.ID>) -> Void)?

	/// Typing changes the board on every keystroke, so writes wait for a pause
	private func scheduleSave() {
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

	private func discardCurrentIfEmpty() {
		guard let currentID, current.isEmpty else { return }
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
		guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
		boards[index].statements.append(statement)
		boards[index].modified = .now
		changedIDs.insert(boardID)
		save()
	}
}
