//
//  BoardStoreTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
@testable import Ergo
import ErgoLogic
import ErgoSync
import Foundation
import Testing

/// Which boards there are, which one is open, and when one is saved, kept or thrown away
@Suite(.cleanDefaults)
struct BoardStoreTests {
	// MARK: - Starting

	@Test func aNewStoreHasNoBoardsAndAnEmptyDraftToWriteOn() {
		let store = BoardStore.test()

		#expect(store.boards.isEmpty)
		#expect(store.currentID == nil)
		#expect(store.current.isEmpty)
		#expect(store.current.statements.count == 1)
	}

	@Test func theStoreOpensWithWhatWasSaved() {
		let board = Board([card("It rained.")])
		Defaults[.boards] = [board]
		Defaults[.currentBoardID] = board.id

		let store = BoardStore()

		#expect(store.boards.map(\.id) == [board.id])
		#expect(store.current.statements == board.statements)
	}

	// MARK: - The draft

	@Test func writingOnTheDraftAddsItToTheList() {
		let store = BoardStore.test()
		var statement = store.current.statements[0]
		statement.english = "It rained."

		store.updateStatement(statement)

		#expect(store.boards.count == 1)
		#expect(store.currentID == store.boards.first?.id)
		#expect(store.current.statements.first?.english == "It rained.")
	}

	/// Where boxes sit isn't writing, so a board of empty cards stays out of the list
	@Test func movingEmptyCardsAroundLeavesTheBoardAsADraft() {
		let store = BoardStore.test()

		store.addStatement(at: CanvasPoint(x: 300, y: 0))

		#expect(store.boards.isEmpty)
		#expect(store.current.statements.count == 2)
	}

	// MARK: - Saving

	@Test func savingWritesTheBoardsToDefaultsAndTellsSync() {
		let board = Board([card("It rained.")])
		let store = BoardStore.test(board)
		let log = store.recordSaves()

		var edited = store.current
		edited.statements[0].english = "It poured."
		store.current = edited
		store.save()

		#expect(Defaults[.boards].first?.statements.first?.english == "It poured.")
		#expect(log.changedIDs == [board.id])
		#expect(log.saves.count == 1)
	}

	@Test func savingAgainWithNothingNewTellsSyncNothing() {
		let store = BoardStore.test(Board([card("It rained.")]))
		let log = store.recordSaves()

		store.save()
		store.save()

		#expect(log.saves.isEmpty)
	}

	@Test func openingABoardRemembersWhichOne() {
		let first = Board([card("First")])
		let second = Board([card("Second")])
		let store = BoardStore.test(first, second)

		store.open(second.id)

		#expect(store.currentID == second.id)
		#expect(Defaults[.currentBoardID] == second.id)
	}

	// MARK: - Leaving a board empty

	@Test func leavingAnEmptyBoardDiscardsItAndReportsItDeleted() {
		let blank = Board()
		let written = Board([card("It rained.")])
		let store = BoardStore.test(blank, written)
		let log = store.recordSaves()

		store.open(written.id)

		#expect(store.boards.map(\.id) == [written.id])
		#expect(log.deletedIDs == [blank.id])
	}

	@Test func leavingABoardWithWritingKeepsIt() {
		let first = Board([card("First")])
		let second = Board([card("Second")])
		let store = BoardStore.test(first, second)

		store.open(second.id)

		#expect(store.boards.count == 2)
	}

	@Test func aBoardWithOnlyASourceIsntEmpty() {
		let store = BoardStore.test(Board([], sources: [textSource()]))

		store.newBoard()

		#expect(store.boards.count == 1)
	}

	@Test func newBoardOpensAFreshDraftAndDiscardsAnEmptyOne() {
		let blank = Board()
		let store = BoardStore.test(blank)

		store.newBoard()

		#expect(store.boards.isEmpty)
		#expect(store.currentID == nil)
		#expect(store.current.id != blank.id)
	}

	@Test func discardingNeverTombstonesASharedBoard() {
		let blank = Board()
		let store = BoardStore.test(blank)
		store.shares[blank.id] = .invited(to: blank, as: .editor)
		let log = store.recordSaves()

		store.discardCurrentIfEmpty()

		#expect(store.boards == [blank])
		#expect(log.deletedIDs.isEmpty)
	}

	// MARK: - Deleting

	@Test func deletingABoardReportsItAndForgetsItsPinAndArchive() {
		let kept = Board([card("Kept")])
		let pinned = Board([card("Pinned")])
		let archived = Board([card("Archived")])
		let store = BoardStore.test(kept, pinned, archived)
		store.setPinned(true, pinned.id)
		store.setArchived(true, archived.id)
		let log = store.recordSaves()

		store.delete([pinned.id, archived.id])

		#expect(store.boards.map(\.id) == [kept.id])
		#expect(log.deletedIDs == [pinned.id, archived.id])
		#expect(store.pinnedIDs.isEmpty)
		#expect(store.archivedIDs.isEmpty)
		#expect(Defaults[.boards].map(\.id) == [kept.id])
	}

	@Test func deletingTheOpenBoardStartsANewDraft() {
		let open = Board([card("Open")])
		let store = BoardStore.test(open)

		store.delete([open.id])

		#expect(store.boards.isEmpty)
		#expect(store.currentID == nil)
		#expect(Defaults[.currentBoardID] == nil)
		#expect(store.current.isEmpty)
	}

	/// For a member, deleting a shared board is leaving it, so it has to get through
	@Test func aViewerCanStillLeaveASharedBoard() {
		let board = Board([card("Shared")])
		let store = BoardStore.test(board)
		store.shares[board.id] = .invited(to: board, as: .viewer)
		let log = store.recordSaves()

		store.delete([board.id])

		#expect(store.boards.isEmpty)
		#expect(log.deletedIDs == [board.id])
	}

	// MARK: - Listing

	/// Added oldest first, so the order of the list is the sort and not the order they went in
	@Test func theListIsNewestFirstWithPinnedOnTop() {
		var old = Board([card("Old")])
		old.modified = Date(timeIntervalSince1970: 100)
		var middle = Board([card("Middle")])
		middle.modified = Date(timeIntervalSince1970: 200)
		var new = Board([card("New")])
		new.modified = Date(timeIntervalSince1970: 300)
		let store = BoardStore.test(old, middle, new)

		#expect(store.sortedBoards.map(\.id) == [new.id, middle.id, old.id])

		store.setPinned(true, old.id)

		#expect(store.listedBoards.map(\.id) == [old.id, new.id, middle.id])
	}

	@Test func archivedBoardsLeaveTheListAndComeBack() {
		let kept = Board([card("Kept")])
		let archived = Board([card("Archived")])
		let store = BoardStore.test(kept, archived)

		store.setArchived(true, archived.id)

		#expect(store.listedBoards.map(\.id) == [kept.id])
		#expect(store.archivedBoards.map(\.id) == [archived.id])

		store.setArchived(false, archived.id)

		#expect(store.listedBoards.count == 2)
		#expect(store.archivedBoards.isEmpty)
	}

	@Test func archivingTheOpenBoardStartsANewOneWithoutDeletingIt() {
		let open = Board([card("Open")])
		let store = BoardStore.test(open)
		let log = store.recordSaves()

		store.setArchived(true, open.id)

		#expect(store.currentID == nil)
		#expect(store.boards.count == 1)
		#expect(log.deletedIDs.isEmpty)
	}

	@Test func archivingUnpins() {
		let board = Board([card("A")])
		let store = BoardStore.test(board)
		store.setPinned(true, board.id)

		store.setArchived(true, board.id)

		#expect(store.pinnedIDs.isEmpty)
	}

	@Test func pinsAndArchivesAreRememberedOnTheDevice() {
		let board = Board([card("A")])
		let store = BoardStore.test(board)

		store.setPinned(true, board.id)

		#expect(Defaults[.pinnedBoards] == [board.id])
	}

	// MARK: - Renaming

	@Test func renamingTrimsTheName() {
		let board = Board([card("It rained.")])
		let store = BoardStore.test(board)

		store.rename(board.id, to: "  Weather \n")

		#expect(store.current.name == "Weather")
		#expect(store.current.title == "Weather")
	}

	@Test func anEmptyNameGoesBackToTheWrittenTitle() {
		var board = Board([card("It rained.")])
		board.name = "Weather"
		let store = BoardStore.test(board)

		store.rename(board.id, to: "   ")

		#expect(store.current.title == "It rained.")
	}

	@Test func renamingReportsTheBoardChanged() {
		let board = Board([card("It rained.")])
		let store = BoardStore.test(board)
		let log = store.recordSaves()

		store.rename(board.id, to: "Weather")
		store.save()

		#expect(log.changedIDs == [board.id])
	}
}
