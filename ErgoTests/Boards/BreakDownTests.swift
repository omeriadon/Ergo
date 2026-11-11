//
//  BreakDownTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

@testable import Ergo
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation
import Testing

/// A server breakdown becoming cards on a board, and the record that finds a running one again
@Suite(.cleanDefaults)
struct BreakDownTests {
	let breakdown = ArgumentBreakdown(
		kind: .argument,
		premises: ["It rained.", "If it rained, the ground is wet."],
		conclusion: "The ground is wet."
	)

	// MARK: - A new board

	@Test func aBreakdownMakesABoardWithItsSourceAndAnArrowFromEveryPremise() throws {
		let store = BoardStore.test()

		store.newBoard(from: breakdown, source: .text("It rained. If it rained, the ground is wet. So the ground is wet."))

		let board = store.current
		let source = try #require(board.sources.first)
		let conclusion = try #require(board.statements.first { $0.english == "The ground is wet." })
		#expect(board.sources.count == 1)
		#expect(board.statements.count == 3)
		#expect(board.links.count == 2)
		#expect(board.links.allSatisfy { $0.conclusion == conclusion.id })
		#expect(store.boards.count == 1)
		#expect(source.content == .text("It rained. If it rained, the ground is wet. So the ground is wet."))
	}

	@Test func everyCardFromABreakdownIsInTheRegionOfItsSource() throws {
		let store = BoardStore.test()

		store.newBoard(from: breakdown, source: .text("Original"))

		let source = try #require(store.current.sources.first)
		#expect(store.current.statements.allSatisfy { $0.source == source.id })
	}

	@Test func theSourceSitsAboveItsCards() throws {
		let store = BoardStore.test()

		store.newBoard(from: breakdown, source: .text("Original"))

		let source = try #require(store.current.sources.first)
		let top = store.current.statements.map(\.position.y).min() ?? 0
		#expect(source.position.y < top)
	}

	@Test func startingFromAnEmptyBoardDiscardsIt() {
		let blank = Board()
		let store = BoardStore.test(blank)

		store.newBoard(from: breakdown, source: .text("Original"))

		#expect(store.boards.count == 1)
		#expect(store.boards.first?.id != blank.id)
	}

	@Test func aBreakdownWithNothingInItMakesNoCards() {
		let store = BoardStore.test()

		store.newBoard(from: ArgumentBreakdown(kind: .statements), source: .text("Original"))

		#expect(store.current.sources.count == 1)
		#expect(store.current.statements.allSatisfy(\.isEmpty))
	}

	// MARK: - On an existing board

	@Test func breakingDownASourceAddsCardsUnderWhatIsThereWithoutMovingIt() {
		let old = card("Already here", x: 0, y: 0)
		let source = textSource("Another article.", x: 0, y: -300)
		let store = BoardStore.test(Board([old], sources: [source]))

		store.breakDown(breakdown, into: source.id)

		let board = store.current
		let added = board.members(of: source.id)
		#expect(board.statement(old.id)?.position == old.position)
		#expect(added.count == 3)
		#expect(added.allSatisfy { $0.position.y > old.position.y + CanvasLayout.boxSize.height })
		#expect(board.links.count == 2)
	}

	@Test func theSourceMovesOntoItsNewCards() throws {
		let old = card("Already here")
		let source = textSource("Another article.", x: 900, y: 900)
		let store = BoardStore.test(Board([old], sources: [source]))

		store.breakDown(breakdown, into: source.id)

		let moved = try #require(store.source(source.id))
		let top = store.current.members(of: source.id).map(\.position.y).min() ?? 0
		#expect(moved.position.y < top)
	}
}

/// What `Defaults[.pendingBreakDown]` remembers, and when a sheet is the one it belongs to
struct PendingBreakDownTests {
	static func request(_ english: String) -> TranslateRequest {
		.test(english)
	}

	static let page = BoardSource.Content.link(URL(string: "https://example.com/post")!, title: nil)

	@Test func theSameTextMatchesEvenWithDifferentSpacing() {
		let pending = PendingBreakDown(request: Self.request("All men are mortal."))

		#expect(pending.matches(english: "  All men are mortal.\n", input: nil, existing: nil))
	}

	@Test func differentTextDoesNotMatch() {
		let pending = PendingBreakDown(request: Self.request("All men are mortal."))

		#expect(!pending.matches(english: "All cats are mammals.", input: nil, existing: nil))
	}

	/// A page shared again is read again and may differ in a few words
	@Test func whenItCameFromAPageThePageDecidesAndNotTheText() {
		let pending = PendingBreakDown(request: Self.request("The page as first read."), input: Self.page)

		#expect(pending.matches(english: "The page as read a minute later.", input: Self.page, existing: nil))
	}

	@Test func aDifferentPageDoesNotMatch() throws {
		let pending = PendingBreakDown(request: Self.request("Same words."), input: Self.page)
		let other = try BoardSource.Content.link(#require(URL(string: "https://example.com/other")), title: nil)

		#expect(!pending.matches(english: "Same words.", input: other, existing: nil))
		#expect(!pending.matches(english: "Same words.", input: nil, existing: nil))
	}

	@Test func aSourceOnTheBoardDecidesWhenThereIsOne() {
		let source = UUID()
		let pending = PendingBreakDown(request: Self.request("Text"), existing: source)

		#expect(pending.matches(english: "Edited text", input: nil, existing: source))
		#expect(!pending.matches(english: "Text", input: nil, existing: UUID()))
		#expect(!pending.matches(english: "Text", input: nil, existing: nil))
	}

	@Test func theSheetShowsTheWholeTextWhenItGoesInParts() {
		let whole = "First part. Second part."
		let parts = PendingBreakDown.Parts(whole: whole, total: 2, waiting: [Self.request("Second part.")])
		let pending = PendingBreakDown(request: Self.request("First part."), parts: parts)

		#expect(pending.text == whole)
		#expect(PendingBreakDown(request: Self.request("Only text")).text == "Only text")
	}

	@Test func partsAreDoneWhenEveryOneHasFinished() {
		let empty = ArgumentBreakdown(kind: .statements)
		let found = ArgumentBreakdown(kind: .argument, premises: ["A"], conclusion: "B")
		var parts = PendingBreakDown.Parts(whole: "A. B.", total: 2, waiting: [])

		#expect(!parts.isDone)

		parts.finished = [.init(text: "A.", breakdown: found)]
		#expect(!parts.isDone)

		parts.finished.append(.init(text: "B.", breakdown: empty))
		#expect(parts.isDone)
		#expect(parts.finished.map(\.hasResult) == [true, false])
	}

	@Test func aPendingBreakdownSurvivesBeingSaved() throws {
		let pending = PendingBreakDown(request: Self.request("Text"), input: Self.page)

		let data = try JSONEncoder().encode(pending)

		#expect(try JSONDecoder().decode(PendingBreakDown.self, from: data) == pending)
	}
}
