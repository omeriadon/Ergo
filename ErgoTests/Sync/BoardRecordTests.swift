//
//  BoardRecordTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

@testable import Ergo
import ErgoLogic
import ErgoProtocol
import ErgoSync
import Foundation
import Testing

/// Boards turned into records and built back from them
struct BoardRecordTests {
	/// Two cards with an arrow between them, and a source with the first of them in its region
	struct Example {
		let source: BoardSource
		let rain: Statement
		let wet: Statement
		let board: Board

		init() {
			let source = textSource("The article.", x: 0, y: 0)
			let rain = card("It rained.", x: 0, y: 300)
			let wet = card("The ground is wet.", x: 0, y: 500)

			var inRegion = rain
			inRegion.source = source.id
			var board = Board([inRegion, wet], links: [arrow(rain, wet)], sources: [source])
			board.name = "Weather"

			self.source = source
			self.rain = rain
			self.wet = wet
			self.board = board
		}
	}

	static func rebuilt(_ board: Board, from replica: SyncReplica, local: [Board] = []) -> BoardRecord.Rebuilt {
		BoardRecord.rebuild([board.id], from: replica, local: local)
	}

	// MARK: - Local to record

	@Test func aBoardsRecordHoldsOnlyItsNameAndWhenItWasMade() throws {
		let fields = try BoardRecord.fields(of: Example().board)

		#expect(Set(fields.keys) == [SyncFieldName.created, SyncFieldName.name])
		#expect(fields[SyncFieldName.name] == .string("Weather"))
	}

	@Test func eachCardArrowAndSourceIsARecordOfItsOwn() throws {
		let example = Example()

		let replica = try SyncReplica.holding(example.board)

		#expect(replica[.board, BoardRecord.id(example.board.id)] != nil)
		#expect(replica[.statement, StatementRecord.id(example.rain.id)] != nil)
		#expect(replica[.statement, StatementRecord.id(example.wet.id)] != nil)
		#expect(replica[.link, LinkRecord.id(example.board.links[0].id)] != nil)
		#expect(replica[.source, SourceRecord.id(example.source.id)] != nil)
		#expect(replica.records.count == 5)
	}

	/// Typing in one box and dragging another must never clash, so a card's English and place are separate fields
	@Test func aCardsEnglishAndPlaceAreSeparateFields() throws {
		let fields = try StatementRecord.fields(of: card("Text", x: 5, y: 6), in: UUID())

		#expect(fields[SyncFieldName.content] != nil)
		#expect(fields[SyncFieldName.position] != nil)
		#expect(fields[SyncFieldName.content] != fields[SyncFieldName.position])
	}

	// MARK: - Record to local

	@Test func aBoardIsBuiltBackFromItsRecords() throws {
		let example = Example()
		let replica = try SyncReplica.holding(example.board)

		let rebuilt = Self.rebuilt(example.board, from: replica)

		let board = try #require(rebuilt.boards.first)
		#expect(board.id == example.board.id)
		#expect(board.name == "Weather")
		#expect(Set(board.statements.map(\.english)) == ["It rained.", "The ground is wet."])
		#expect(board.links == example.board.links)
		#expect(board.sources == example.board.sources)
		#expect(rebuilt.deleted.isEmpty)
	}

	@Test func aCardKeepsItsPlaceAndRegion() throws {
		let example = Example()
		let replica = try SyncReplica.holding(example.board)

		let board = try #require(Self.rebuilt(example.board, from: replica).boards.first)

		let rain = try #require(board.statement(example.rain.id))
		#expect(rain.position == example.rain.position)
		#expect(rain.source == example.source.id)
		#expect(board.statement(example.wet.id)?.source == nil)
	}

	@Test func aBoardOnlyTheReplicaKnowsIsBuiltWithoutAnythingLocal() throws {
		let example = Example()
		let replica = try SyncReplica.holding(example.board)

		let rebuilt = Self.rebuilt(example.board, from: replica, local: [])

		#expect(rebuilt.boards.count == 1)
	}

	@Test func theLocalOrderOfCardsIsKept() throws {
		let example = Example()
		let replica = try SyncReplica.holding(example.board)
		var local = example.board
		local.statements.reverse()

		let board = try #require(Self.rebuilt(example.board, from: replica, local: [local]).boards.first)

		#expect(board.statements.map(\.id) == local.statements.map(\.id))
	}

	@Test func anEditFromAnotherDeviceReplacesTheLocalEnglish() throws {
		let example = Example()
		var remote = example.board
		remote.statements[0].english = "It poured."
		let replica = try SyncReplica.holding(remote)

		let board = try #require(Self.rebuilt(example.board, from: replica, local: [example.board]).boards.first)

		#expect(board.statement(example.rain.id)?.english == "It poured.")
	}

	@Test func aCardNotRecordedYetIsKept() throws {
		let example = Example()
		let replica = try SyncReplica.holding(example.board)
		var local = example.board
		let unsent = card("Written offline", x: 600)
		local.statements.append(unsent)

		let board = try #require(Self.rebuilt(example.board, from: replica, local: [local]).boards.first)

		#expect(board.statement(unsent.id)?.english == "Written offline")
	}

	// MARK: - In whatever order they arrive

	@Test func recordsBeforeTheirBoardBuildNothing() throws {
		let example = Example()
		let replica = try SyncReplica.holding(example.board)
			.without(SyncRecord.Key(kind: .board, id: BoardRecord.id(example.board.id)))

		let rebuilt = Self.rebuilt(example.board, from: replica)

		#expect(rebuilt.boards.isEmpty)
		#expect(rebuilt.deleted.isEmpty)
	}

	@Test func anArrowWaitsForItsCardAndThenAppears() throws {
		let example = Example()
		let complete = try SyncReplica.holding(example.board)
		let partial = complete.without(SyncRecord.Key(kind: .statement, id: StatementRecord.id(example.wet.id)))

		let early = try #require(Self.rebuilt(example.board, from: partial).boards.first)
		let late = try #require(Self.rebuilt(example.board, from: complete).boards.first)

		#expect(early.links.isEmpty)
		#expect(late.links == example.board.links)
		#expect(early.statements.map(\.english) == ["It rained."])
	}

	@Test func theSameRecordsBuildTheSameBoardWhateverWasLocal() throws {
		let example = Example()
		let replica = try SyncReplica.holding(example.board)

		let fresh = try #require(Self.rebuilt(example.board, from: replica).boards.first)
		let again = try #require(Self.rebuilt(example.board, from: replica, local: [fresh]).boards.first)

		#expect(Set(fresh.statements) == Set(again.statements))
		#expect(fresh.links == again.links)
		#expect(fresh.sources == again.sources)
	}

	// MARK: - Deleting

	@Test func aDeletedBoardIsReportedDeletedAndNotBuilt() throws {
		let example = Example()
		var replica = try SyncReplica.holding(example.board)
		replica.recordLocal(kind: .board, id: BoardRecord.id(example.board.id), fields: [SyncFieldName.deleted: true])

		let rebuilt = Self.rebuilt(example.board, from: replica)

		#expect(rebuilt.boards.isEmpty)
		#expect(rebuilt.deleted == [example.board.id])
	}

	/// Only the board has a tombstone. Its cards, arrows and sources are ignored with it, and the server prunes them.
	@Test func aDeletedBoardsRecordsAreIgnored() throws {
		let example = Example()
		var replica = try SyncReplica.holding(example.board)
		replica.recordLocal(kind: .board, id: BoardRecord.id(example.board.id), fields: [SyncFieldName.deleted: true])

		let cards = replica.records.values.filter { $0.kind == .statement || $0.kind == .link || $0.kind == .source }

		#expect(cards.count == 4)
		#expect(cards.allSatisfy { replica.isIgnored($0) })
		#expect(cards.allSatisfy { !$0.isDeleted })
	}

	@Test func aDeletedCardIsLeftOut() throws {
		let example = Example()
		var replica = try SyncReplica.holding(example.board)
		replica.recordLocal(kind: .statement, id: StatementRecord.id(example.wet.id), fields: [SyncFieldName.deleted: true])

		let board = try #require(Self.rebuilt(example.board, from: replica).boards.first)

		#expect(board.statements.map(\.id) == [example.rain.id])
		#expect(board.links.isEmpty)
	}

	// MARK: - Never empty

	@Test func aBoardWithNothingOnItGetsOneEmptyCard() throws {
		let bare = Board([], sources: [])
		let replica = try SyncReplica.holding(bare)

		let board = try #require(Self.rebuilt(bare, from: replica).boards.first)

		#expect(board.statements.count == 1)
		#expect(board.statements[0].isEmpty)
	}

	@Test func aBoardWithOnlyASourceGetsNoEmptyCard() throws {
		let bare = Board([], sources: [textSource()])
		let replica = try SyncReplica.holding(bare)

		let board = try #require(Self.rebuilt(bare, from: replica).boards.first)

		#expect(board.statements.isEmpty)
		#expect(board.sources.count == 1)
	}

	@Test func rebuildingDoesNotKeepMakingNewEmptyCards() throws {
		let bare = Board([], sources: [])
		let replica = try SyncReplica.holding(bare)

		let first = try #require(Self.rebuilt(bare, from: replica).boards.first)
		let second = try #require(Self.rebuilt(bare, from: replica, local: [first]).boards.first)

		#expect(second.statements.map(\.id) == first.statements.map(\.id))
	}

	// MARK: - Arrows that would be wrong

	@Test func arrowsThatLoopAreDroppedTheSameWayOnEveryDevice() throws {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		let forwards = arrow(rain, wet)
		let backwards = arrow(wet, rain)
		var board = Board([rain, wet], links: [forwards, backwards])
		board.name = "Loop"
		let replica = try SyncReplica.holding(board)

		let first = try #require(Self.rebuilt(board, from: replica).boards.first)
		let second = try #require(Self.rebuilt(board, from: replica, local: [first]).boards.first)

		#expect(first.links.count == 1)
		#expect(first.links == second.links)
	}

	// MARK: - Damaged records

	@Test func aRecordThatIsntAnIdCantBeRead() {
		let record = SyncRecord(kind: .board, id: "not-an-id")

		#expect(!BoardRecord.canRead(record))
	}

	@Test func aBoardRecordWithADamagedNameCantBeRead() throws {
		let board = Board([card("Rain")])
		var replica = try SyncReplica.holding(board)
		replica.recordLocal(kind: .board, id: BoardRecord.id(board.id), fields: [SyncFieldName.name: 42])
		let record = try #require(replica[.board, BoardRecord.id(board.id)])

		#expect(!BoardRecord.canRead(record))
		#expect(Self.rebuilt(board, from: replica, local: [board]).boards.isEmpty)
	}

	@Test func aStatementWithNoContentAndNothingLocalCantBeRead() {
		let record = SyncRecord(kind: .statement, id: UUID().uuidString)

		#expect(!StatementRecord.canRead(record))
	}

	@Test func aLinkNeedsBothEnds() {
		let one = SyncRecord(kind: .link, id: UUID().uuidString, fields: [:])

		#expect(LinkRecord.link(from: one) == nil)
	}

	@Test func aSourceOfAKindThisVersionDoesntKnowCantBeRead() throws {
		let source = textSource("Text")
		let board = Board([card("Rain")], sources: [source])
		var replica = try SyncReplica.holding(board)
		replica.recordLocal(kind: .source, id: SourceRecord.id(source.id), fields: [SyncFieldName.content: ["type": "video", "url": "https://example.com/v"]])
		let record = try #require(replica[.source, SourceRecord.id(source.id)])

		#expect(!SourceRecord.canRead(record))
	}

	// MARK: - Round trips

	@Test func aLinkSourceSurvivesItsRecord() throws {
		let source = try BoardSource(position: CanvasPoint(x: 4, y: 5), content: .link(#require(URL(string: "https://example.com/post")), title: "Post"))
		let fields = try SourceRecord.fields(of: source, in: UUID())
		let stamp = SyncStamp(time: 1, counter: 0, device: "a")
		let record = SyncRecord(kind: .source, id: SourceRecord.id(source.id), fields: fields.mapValues { SyncField(value: $0, stamp: stamp) })

		#expect(SourceRecord.source(from: record, local: nil) == source)
	}

	@Test func aLinkSurvivesItsRecord() {
		let link = Link(premise: UUID(), conclusion: UUID())
		let stamp = SyncStamp(time: 1, counter: 0, device: "a")
		let fields = LinkRecord.fields(of: link, in: UUID())
		let record = SyncRecord(kind: .link, id: LinkRecord.id(link.id), fields: fields.mapValues { SyncField(value: $0, stamp: stamp) })

		#expect(LinkRecord.link(from: record) == link)
	}
}
