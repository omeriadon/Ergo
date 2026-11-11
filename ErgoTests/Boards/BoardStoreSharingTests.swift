//
//  BoardStoreSharingTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
@testable import Ergo
import ErgoLogic
import ErgoProtocol
import ErgoSync
import Foundation
import Testing

/// What a person can do to a board that's shared with them, and how changes from other devices arrive
@Suite(.cleanDefaults)
struct BoardStoreSharingTests {
	let rain = card("Rain")
	let wet = card("Wet", y: 200)

	/// A store with one open board, shared with this person as `role`
	func sharedStore(as role: BoardRole) -> (store: BoardStore, board: Board) {
		let board = Board([rain, wet])
		let store = BoardStore.test(board)
		store.shares[board.id] = .invited(to: board, as: role)
		return (store, board)
	}

	// MARK: - Who can edit

	@Test func aBoardThatIsntSharedCanBeEdited() {
		let store = BoardStore.test(Board([rain]))

		#expect(store.canEdit(store.current.id))
	}

	@Test(arguments: [BoardRole.owner, .editor])
	func ownersAndEditorsCanEdit(role: BoardRole) {
		let (store, board) = sharedStore(as: role)

		store.updateStatement(Statement(id: rain.id, position: rain.position, english: "It rained."))

		#expect(store.canEdit(board.id))
		#expect(store.statement(rain.id)?.english == "It rained.")
	}

	@Test func aViewerCantEdit() {
		let (store, board) = sharedStore(as: .viewer)

		#expect(!store.canEdit(board.id))
	}

	// MARK: - A viewer's edits go nowhere

	@Test func aViewerCantChangeACard() {
		let (store, board) = sharedStore(as: .viewer)

		store.updateStatement(Statement(id: rain.id, position: rain.position, english: "Changed"))
		store.moveStatement(id: rain.id, to: CanvasPoint(x: 900, y: 900))
		store.deleteStatement(id: wet.id)
		store.addStatement(at: CanvasPoint(x: 400, y: 400))

		#expect(store.current == board)
		#expect(store.changedIDs.isEmpty)
	}

	@Test func aViewerCantDrawOrRemoveArrows() {
		let (store, board) = sharedStore(as: .viewer)

		store.link(premise: rain.id, conclusion: wet.id)

		#expect(store.current.links.isEmpty)
		#expect(store.current == board)
	}

	@Test func aViewerCantRemoveAnArrow() {
		let link = arrow(rain, wet)
		let board = Board([rain, wet], links: [link])
		let store = BoardStore.test(board)
		store.shares[board.id] = .invited(to: board, as: .viewer)

		store.unlink(id: link.id)

		#expect(store.current.links == [link])
	}

	@Test func aViewerCantAddMoveOrDeleteSources() {
		let source = textSource()
		let board = Board([rain], sources: [source])
		let store = BoardStore.test(board)
		store.shares[board.id] = .invited(to: board, as: .viewer)

		store.addSource(.text("Another"), at: .zero)
		store.moveSource(id: source.id, to: CanvasPoint(x: 500, y: 500))
		store.updateSource(source.id, content: .text("Changed"))
		store.deleteSource(id: source.id)

		#expect(store.current == board)
	}

	@Test func aViewerCantArrangeOrRename() {
		let (store, board) = sharedStore(as: .viewer)

		store.arrange()
		store.rename(board.id, to: "Mine now")

		#expect(store.current == board)
		#expect(store.changedIDs.isEmpty)
	}

	/// Every edit comes through `current`'s setter, so that is the one place that has to hold
	@Test func aViewerCantSetTheCurrentBoardDirectly() {
		let (store, board) = sharedStore(as: .viewer)
		var edited = board
		edited.statements[0].english = "Changed"

		store.current = edited

		#expect(store.current == board)
	}

	@Test func aViewerStillSeesTheirBoardInTheList() {
		let (store, board) = sharedStore(as: .viewer)

		#expect(store.listedBoards.map(\.id) == [board.id])
	}

	// MARK: - Conflict copies

	@Test func aConflictCopyIsRefusedOnAViewersBoard() {
		let (store, board) = sharedStore(as: .viewer)

		store.insertStatementCopy(card("Lost edit"), into: board.id)

		#expect(store.current == board)
	}

	@Test func aConflictCopyIsAddedAndReportedOnAnEditorsBoard() {
		let (store, board) = sharedStore(as: .editor)
		let log = store.recordSaves()

		store.insertStatementCopy(card("Lost edit"), into: board.id)

		#expect(store.current.statements.map(\.english) == ["Rain", "Wet", "Lost edit"])
		#expect(log.changedIDs == [board.id])
	}

	/// Nothing may be lost, so a copy goes in even when the board is full
	@Test func aConflictCopyIgnoresTheLimitOnCards() {
		let limit = ArgumentMapValidator.defaultMaximumStatements
		let full = Board((0 ..< limit).map { card("Claim \($0)", x: Double($0) * 300) })
		let store = BoardStore.test(full)

		store.insertStatementCopy(card("Lost edit"), into: full.id)

		#expect(store.current.statements.count == limit + 1)
	}

	@Test func aConflictCopyForABoardThatIsntThereIsDropped() {
		let store = BoardStore.test(Board([rain]))

		store.insertStatementCopy(card("Lost edit"), into: UUID())

		#expect(store.current.statements.count == 1)
	}
}

/// Changes other devices made, which are written without being sent back
@Suite(.cleanDefaults)
struct BoardStoreRemoteChangeTests {
	@Test func aRemoteBoardIsAddedWithoutBeingReportedBack() {
		let store = BoardStore.test()
		let log = store.recordSaves()
		let remote = Board([card("From another device")])

		store.applyRemote([remote], deleted: [])
		store.save()

		#expect(store.boards.map(\.id) == [remote.id])
		#expect(log.saves.isEmpty)
	}

	@Test func aRemoteChangeIsSavedOnThisDevice() {
		let board = Board([card("Before")])
		let store = BoardStore.test(board)
		var remote = board
		remote.statements[0].english = "After"

		store.applyRemote([remote], deleted: [])

		#expect(Defaults[.boards].first?.statements.first?.english == "After")
	}

	@Test func aRemoteChangeToTheOpenBoardCountsAsAnEdit() {
		let board = Board([card("Before")])
		let store = BoardStore.test(board)
		var remote = board
		remote.statements[0].english = "After"

		store.applyRemote([remote], deleted: [])

		#expect(store.remoteEdits == 1)
		#expect(store.current.statements.first?.english == "After")
	}

	/// Only the newest stamp moving, which is what every sync does to a board it didn't change
	@Test func aRemoteChangeThatOnlyMovesTheDateIsNotAnEdit() {
		let board = Board([card("Same")])
		let store = BoardStore.test(board)
		var remote = board
		remote.modified = Date(timeIntervalSince1970: 42)

		store.applyRemote([remote], deleted: [])

		#expect(store.remoteEdits == 0)
		#expect(store.current.modified == Date(timeIntervalSince1970: 42))
	}

	@Test func aRemoteChangeToAnotherBoardIsNotCounted() {
		let open = Board([card("Open")])
		let other = Board([card("Other")])
		let store = BoardStore.test(open, other)
		var remote = other
		remote.statements[0].english = "Changed elsewhere"

		store.applyRemote([remote], deleted: [])

		#expect(store.remoteEdits == 0)
	}

	@Test func aBoardDeletedElsewhereGoesAndTheOpenOneBecomesADraft() {
		let board = Board([card("Gone")])
		let store = BoardStore.test(board)
		store.setPinned(true, board.id)

		store.applyRemote([], deleted: [board.id])

		#expect(store.boards.isEmpty)
		#expect(store.currentID == nil)
		#expect(store.current.isEmpty)
		#expect(store.pinnedIDs.isEmpty)
	}

	@Test func nothingRemoteDoesNothing() {
		let board = Board([card("Same")])
		let store = BoardStore.test(board)

		store.applyRemote([], deleted: [])

		#expect(store.boards == [board])
	}
}
