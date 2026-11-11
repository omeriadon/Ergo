//
//  SyncControllerTests.swift
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

/// What a device tells the replica when boards change. The controller here has never run, so nothing reaches a server.
@Suite(.cleanDefaults)
struct SyncControllerRecordingTests {
	let rain = card("It rained.")
	let wet = card("The ground is wet.", y: 200)

	// MARK: - Signed in and out

	@Test func aSignedOutDeviceRecordsNothing() {
		let board = Board([rain])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store, signedIn: false)

		sync.record([board], deleted: [])

		#expect(sync.replica.records.isEmpty)
	}

	@Test func aSavedBoardBecomesRecordsOfEachKind() {
		let source = textSource()
		let board = Board([rain, wet], links: [arrow(rain, wet)], sources: [source])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store)

		sync.record([board], deleted: [])

		#expect(sync.isAlive(.board, board.id))
		#expect(sync.isAlive(.statement, rain.id))
		#expect(sync.isAlive(.statement, wet.id))
		#expect(sync.isAlive(.link, board.links[0].id))
		#expect(sync.isAlive(.source, source.id))
	}

	/// The store reports every save to the controller, which is how an edit reaches sync
	@Test func anEditInTheStoreIsRecordedWhenSaved() {
		let board = Board([rain])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store)

		store.updateStatement(Statement(id: rain.id, position: rain.position, english: "It poured."))
		store.save()

		let record = sync.replica[.statement, StatementRecord.id(rain.id)]
		#expect(record?.fields[SyncFieldName.content] != nil)
		#expect(sync.isAlive(.board, board.id))
		#expect(!sync.replica.pending.isEmpty)
	}

	@Test func recordingTheSameBoardAgainChangesNothing() {
		let board = Board([rain, wet], links: [arrow(rain, wet)])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store)

		sync.record([board], deleted: [])
		let once = sync.replica

		sync.record([board], deleted: [])

		#expect(sync.replica == once)
	}

	// MARK: - Deleting

	/// The cards, arrows and sources are ignored with their board, and the server prunes them
	@Test func aDeletedBoardWritesOnlyItsTombstone() {
		let source = textSource()
		let board = Board([rain, wet], links: [arrow(rain, wet)], sources: [source])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store)
		sync.record([board], deleted: [])

		store.delete([board.id])

		#expect(sync.isDeleted(.board, board.id))
		#expect(!sync.isDeleted(.statement, rain.id))
		#expect(!sync.isDeleted(.statement, wet.id))
		#expect(!sync.isDeleted(.link, board.links[0].id))
		#expect(!sync.isDeleted(.source, source.id))
	}

	@Test func deletingACardWritesATombstoneForItAndItsArrows() {
		let link = arrow(rain, wet)
		let board = Board([rain, wet], links: [link])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store)
		sync.record([board], deleted: [])

		store.deleteStatement(id: rain.id)
		store.save()

		#expect(sync.isDeleted(.statement, rain.id))
		#expect(sync.isDeleted(.link, link.id))
		#expect(sync.isAlive(.statement, wet.id))
	}

	@Test func deletingASourceWritesATombstoneForIt() {
		let source = textSource()
		let board = Board([rain], sources: [source])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store)
		sync.record([board], deleted: [])

		store.deleteSource(id: source.id)
		store.save()

		#expect(sync.isDeleted(.source, source.id))
		#expect(sync.isAlive(.statement, rain.id))
	}

	// MARK: - Boards that can't be edited

	@Test func aViewOnlyBoardIsNeverRecorded() {
		let board = Board([rain, wet], links: [arrow(rain, wet)])
		let store = BoardStore.test(board)
		// The controller reads who's on each board from its replica when it's made, so the role is set after
		let sync = SyncController.test(boards: store)
		store.shares[board.id] = .invited(to: board, as: .viewer)

		sync.record([board], deleted: [])

		#expect(sync.replica.records.isEmpty)
	}

	@Test(arguments: [BoardRole.owner, .editor])
	func aBoardYouCanEditIsRecorded(role: BoardRole) {
		let board = Board([rain])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store)
		store.shares[board.id] = .invited(to: board, as: role)

		sync.record([board], deleted: [])

		#expect(sync.isAlive(.board, board.id))
	}

	/// For a member, a board's tombstone is leaving it, so it has to go even though nothing else does
	@Test func aViewerLeavingStillWritesTheTombstone() {
		let board = Board([rain])
		let store = BoardStore.test(board)
		let sync = SyncController.test(boards: store)
		store.shares[board.id] = .invited(to: board, as: .viewer)

		sync.record([], deleted: [board.id])

		#expect(sync.isDeleted(.board, board.id))
	}

	// MARK: - Catching up after being signed out

	@Test func aBoardDeletedWhileSignedOutIsDeletedOnSigningIn() throws {
		let gone = Board([rain])
		let kept = Board([wet])
		let store = BoardStore.test(kept)
		let sync = SyncController.test(boards: store)
		sync.replica = try SyncReplica.holding(gone, kept)

		sync.recordAll()

		#expect(sync.isDeleted(.board, gone.id))
		#expect(sync.isAlive(.board, kept.id))
	}

	/// A shared board missing here might just have failed to decode, and deleting it would delete it for everyone
	@Test func aSharedBoardIsNeverDeletedForBeingMissing() throws {
		let shared = Board([rain])
		let store = BoardStore.test(Board([wet]))
		let sync = SyncController.test(boards: store)
		sync.replica = try SyncReplica.holding(shared).with(.share(of: shared, as: .editor))

		sync.recordAll()

		#expect(!sync.isDeleted(.board, shared.id))
	}

	@Test func theStoreReadsWhoIsOnABoardFromTheReplica() throws {
		let shared = Board([rain])
		let store = BoardStore.test(Board([wet]))
		let sync = SyncController.test(boards: store)
		sync.replica = try SyncReplica.holding(shared).with(.share(of: shared, as: .viewer))

		let shares = BoardShareRecords.shares(in: sync.replica)

		#expect(shares[shared.id]?.role == .viewer)
	}
}

/// Who is on a shared board, read from the records the server writes
struct BoardShareRecordsTests {
	@Test func aShareRecordIsReadAsAShare() throws {
		let board = Board([card("Rain")])
		let replica = try SyncReplica.holding(board).with(.share(of: board, as: .editor))

		let shares = BoardShareRecords.shares(in: replica)

		#expect(shares[board.id]?.role == .editor)
		#expect(BoardShareRecords.isShared(board.id.uuidString, in: replica))
	}

	@Test func aBoardWithNoShareRecordIsNotShared() throws {
		let board = Board([card("Rain")])
		let replica = try SyncReplica.holding(board)

		#expect(BoardShareRecords.shares(in: replica).isEmpty)
		#expect(!BoardShareRecords.isShared(board.id.uuidString, in: replica))
	}

	/// Signing in as someone else must not leave the last person's boards behind
	@Test func changingAccountDropsBoardsSharedByOthersAndKeepsOwnedOnes() throws {
		let theirs = Board([card("Theirs")])
		let mine = Board([card("Mine")])
		let replica = try SyncReplica.holding(theirs, mine)
			.with(.share(of: theirs, as: .editor))
			.with(.share(of: mine, as: .owner))

		let departure = BoardShareRecords.departure(from: replica)

		#expect(departure.boards == [theirs.id])
		#expect(departure.records.contains(SyncRecord.Key(kind: .board, id: theirs.id.uuidString)))
		#expect(!departure.records.contains(SyncRecord.Key(kind: .board, id: mine.id.uuidString)))
		#expect(departure.records.contains(SyncRecord.Key(kind: .share, id: mine.id.uuidString)))
	}

	@Test func leavingTakesTheCardsOfTheSharedBoardToo() throws {
		let theirs = Board([card("Theirs")])
		let replica = try SyncReplica.holding(theirs).with(.share(of: theirs, as: .viewer))

		let departure = BoardShareRecords.departure(from: replica)

		#expect(departure.records.contains(SyncRecord.Key(kind: .statement, id: theirs.statements[0].id.uuidString)))
	}

	@Test func rolesHaveWords() {
		#expect(BoardRole.viewer.label == "View only")
		#expect(BoardRole.editor.label == "Can edit")
		#expect(BoardRole.owner.label == "Owner")
	}

	@Test func theSharingNameIsTrimmedAndLimited() {
		#expect(SharingName.cleaned("  Ada \n") == "Ada")
		#expect(SharingName.isValid("Ada"))
		#expect(!SharingName.isValid("   "))
		#expect(!SharingName.isValid(String(repeating: "a", count: SharingName.limit + 1)))
		#expect(SharingName.problem(with: String(repeating: "a", count: SharingName.limit + 1)) != nil)
		#expect(SharingName.problem(with: "") == nil)
	}
}
