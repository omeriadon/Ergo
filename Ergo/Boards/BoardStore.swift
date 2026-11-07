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
	private(set) var remoteEdits = 0

	@ObservationIgnored
	private var saveTask: Task<Void, Never>?

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

		var statement = Statement(position: position)
		statement.source = board.home(of: statement)
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

	/// Sets the centre of the box, which can take it in or out of a region. Call it when a drag ends: sync writes the
	/// position as its own field, and every call restarts the save timer.
	func moveStatement(id: Statement.ID, to position: CanvasPoint) {
		var board = current
		guard let index = board.statements.firstIndex(where: { $0.id == id }), board.statements[index].position != position else { return }
		board.statements[index].position = position
		board.statements[index].source = board.home(of: board.statements[index])
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
		if board.statements.isEmpty, board.sources.isEmpty {
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
		board.map = CanvasLayout.arranged(board.map)
		board.settleSources()
		guard board != current else { return }
		current = board
	}

	// MARK: - breaking down

	/// Opens a new board holding a server breakdown: a statement per premise and one for the conclusion, every premise linked
	/// to it (`ArgumentBreakdown.applied`), all in a region on `content`, which is what was broken down. The breakdown's
	/// claims are dropped, since a board holds English only. Statements past the limit are left out.
	func newBoard(from breakdown: ArgumentBreakdown, source content: BoardSource.Content) {
		newBoard()

		var board = current
		let source = BoardSource(position: .zero, content: content)
		board.sources = [source]
		put(breakdown, into: &board, from: source.id)
		current = board
	}

	/// Puts a breakdown of one of the current board's sources under everything on the board, and moves the source onto it.
	/// Nothing already there moves.
	func breakDown(_ breakdown: ArgumentBreakdown, into source: BoardSource.ID) {
		var board = current
		put(breakdown, into: &board, from: source)
		current = board
	}

	private func put(_ breakdown: ArgumentBreakdown, into board: inout Board, from source: BoardSource.ID) {
		let application = breakdown.applied(to: board.map, replacing: board.hasOnlyPlaceholder)
		board.map = application.map

		// `applied` only knows about statements, so it's kept clear of other sources here
		let added = Set(application.added)
		let top = board.statements.filter { added.contains($0.id) }.map(\.position.y).min() ?? 0
		let room = CanvasRegion.padding + CanvasLayout.boxSize.height * 2 + CanvasLayout.rowGap
		let lowest = board.sources.filter { $0.id != source }.map(\.position.y).max()
		let shift = lowest.map { max($0 + room - top, 0) } ?? 0

		for index in board.statements.indices where added.contains(board.statements[index].id) {
			board.statements[index].position.y += shift
			board.statements[index].source = source
		}

		let cards = board.members(of: source).map(\.position)
		if let position = CanvasRegion.sourcePosition(above: cards), let index = board.sources.firstIndex(where: { $0.id == source }) {
			board.sources[index].position = position
		}
	}

	// MARK: - sources

	func source(_ id: BoardSource.ID) -> BoardSource? {
		current.source(id)
	}

	/// A new source at `position`, in place of the empty card a new board starts with
	@discardableResult
	func addSource(_ content: BoardSource.Content, at position: CanvasPoint) -> BoardSource.ID {
		var board = current
		if board.hasOnlyPlaceholder {
			board.statements = []
		}
		let source = BoardSource(position: position, content: content)
		board.sources.append(source)
		current = board
		return source.id
	}

	/// A new source under everything on the board, for when nobody's looking at the canvas to say where
	func addSource(_ content: BoardSource.Content) {
		let board = current
		let rects = board.hasOnlyPlaceholder ? board.sources.map { CanvasRect.box(at: $0.position) } : board.occupiedRects
		let position = if let left = rects.map(\.minX).min(), let bottom = rects.map(\.maxY).max() {
			CanvasGrid.snapped(CanvasPoint(x: left + CanvasLayout.boxSize.width / 2, y: bottom + CanvasLayout.rowGap))
		} else {
			CanvasPoint.zero
		}
		addSource(content, at: position)
	}

	func updateSource(_ id: BoardSource.ID, content: BoardSource.Content) {
		var board = current
		guard let index = board.sources.firstIndex(where: { $0.id == id }), board.sources[index].content != content else { return }
		board.sources[index].content = content
		current = board
	}

	/// Moves the source and its cards together, so the region keeps its shape
	func moveSource(id: BoardSource.ID, to position: CanvasPoint) {
		var board = current
		guard let index = board.sources.firstIndex(where: { $0.id == id }), board.sources[index].position != position else { return }
		let travel = position - board.sources[index].position
		board.sources[index].position = position
		for card in board.statements.indices where board.statements[card].source == id {
			board.statements[card].position = board.statements[card].position + travel
		}
		current = board
	}

	/// The cards stay, without the region around them. A board never ends up with nothing on it.
	func deleteSource(id: BoardSource.ID) {
		var board = current
		guard let index = board.sources.firstIndex(where: { $0.id == id }) else { return }
		let position = board.sources[index].position
		board.sources.remove(at: index)
		for card in board.statements.indices where board.statements[card].source == id {
			board.statements[card].source = nil
		}
		if board.statements.isEmpty, board.sources.isEmpty {
			board.statements = [Statement(position: position)]
		}
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
