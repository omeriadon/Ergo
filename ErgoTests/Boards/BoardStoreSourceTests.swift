//
//  BoardStoreSourceTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

@testable import Ergo
import ErgoLogic
import Foundation
import Testing

/// Sources on the canvas, and the regions they make with the cards that came from them
@Suite(.cleanDefaults)
struct BoardStoreSourceTests {
	/// A source with two cards under it, in its region, and one card on its own far away
	struct Scene {
		var source = textSource("The article.", x: 0, y: 0)
		var first = card("First", x: 0, y: 300)
		var second = card("Second", x: 0, y: 500)
		var outsider = card("Outsider", x: 3000, y: 300)

		var board: Board {
			var first = first
			first.source = source.id
			var second = second
			second.source = source.id
			return Board([first, second, outsider], links: [arrow(first, second)], sources: [source])
		}
	}

	// MARK: - Adding

	@Test func aNewSourceTakesThePlaceOfTheEmptyStartingCard() {
		let store = BoardStore.test()

		let id = store.addSource(.text("Pasted text."), at: CanvasPoint(x: 10, y: 20))

		#expect(store.current.statements.isEmpty)
		#expect(store.source(id)?.position == CanvasPoint(x: 10, y: 20))
		#expect(store.source(id)?.content == .text("Pasted text."))
		#expect(store.boards.count == 1)
	}

	@Test func aNewSourceLeavesWrittenCardsAlone() {
		let store = BoardStore.test(Board([card("It rained.")]))

		store.addSource(.text("Pasted text."), at: .zero)

		#expect(store.current.statements.map(\.english) == ["It rained."])
		#expect(store.current.sources.count == 1)
	}

	@Test func aSourceWithNoPlaceGoesUnderEverything() throws {
		let lowest = card("Lowest", x: 100, y: 600)
		let store = BoardStore.test(Board([card("High", x: 100, y: 0), lowest]))

		try store.addSource(.link(#require(URL(string: "https://example.com")), title: "Example"))

		let source = try #require(store.current.sources.first)
		#expect(source.position.y > lowest.position.y + CanvasLayout.boxSize.height)
	}

	@Test func aSourceOnABoardWithNothingGoesAtTheOrigin() throws {
		let store = BoardStore.test()

		store.addSource(.text("Pasted text."))

		let source = try #require(store.current.sources.first)
		#expect(source.position == .zero)
	}

	// MARK: - Updating

	@Test func updatingASourceChangesItsContent() {
		let source = textSource("Before")
		let store = BoardStore.test(Board([card("A")], sources: [source]))

		store.updateSource(source.id, content: .text("After"))

		#expect(store.source(source.id)?.content == .text("After"))
	}

	@Test func updatingASourceToWhatItAlreadyIsChangesNothing() {
		let source = textSource("Same")
		let store = BoardStore.test(Board([card("A")], sources: [source]))
		let log = store.recordSaves()

		store.updateSource(source.id, content: .text("Same"))
		store.save()

		#expect(log.saves.isEmpty)
	}

	// MARK: - Moving

	@Test func movingASourceMovesItsCardsTogether() {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		store.moveSource(id: scene.source.id, to: CanvasPoint(x: 100, y: -50))

		let travel = CanvasPoint(x: 100, y: -50)
		#expect(store.source(scene.source.id)?.position == travel)
		#expect(store.statement(scene.first.id)?.position == scene.first.position + travel)
		#expect(store.statement(scene.second.id)?.position == scene.second.position + travel)
	}

	@Test func movingASourceLeavesOtherCardsWhereTheyAre() {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		store.moveSource(id: scene.source.id, to: CanvasPoint(x: 100, y: -50))

		#expect(store.statement(scene.outsider.id)?.position == scene.outsider.position)
	}

	// MARK: - Deleting

	@Test func deletingASourceKeepsItsCardsWithoutTheRegion() {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		store.deleteSource(id: scene.source.id)

		#expect(store.current.sources.isEmpty)
		#expect(store.current.statements.count == 3)
		#expect(store.current.statements.allSatisfy { $0.source == nil })
	}

	/// A board is never without something on it
	@Test func deletingTheOnlySourceLeavesAnEmptyCardInItsPlace() {
		let source = textSource("Only", x: 70, y: 90)
		let store = BoardStore.test(Board([], sources: [source]))

		store.deleteSource(id: source.id)

		#expect(store.current.sources.isEmpty)
		#expect(store.current.statements.count == 1)
		#expect(store.current.statements.first?.isEmpty == true)
		#expect(store.current.statements.first?.position == source.position)
	}

	// MARK: - Regions

	@Test func aCardPutDownInsideARegionJoinsIt() {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		store.moveStatement(id: scene.outsider.id, to: scene.first.position)

		#expect(store.statement(scene.outsider.id)?.source == scene.source.id)
	}

	@Test func aCardAddedInsideARegionJoinsIt() throws {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		let id = try #require(store.addStatement(at: scene.second.position))

		#expect(store.statement(id)?.source == scene.source.id)
	}

	@Test func aCardAddedFarFromEveryRegionBelongsToNone() throws {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		let id = try #require(store.addStatement(at: CanvasPoint(x: -5000, y: -5000)))

		#expect(store.statement(id)?.source == nil)
	}

	@Test func aCardDraggedFarFromItsRegionLeaves() {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		store.moveStatement(id: scene.second.id, to: CanvasPoint(x: 5000, y: 5000))

		#expect(store.statement(scene.second.id)?.source == nil)
	}

	@Test func aCardNudgedWithinItsRegionStays() {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		store.moveStatement(id: scene.second.id, to: scene.second.position + CanvasPoint(x: 40, y: 20))

		#expect(store.statement(scene.second.id)?.source == scene.source.id)
	}

	@Test func theRegionOfASourceHasItsCardsInside() throws {
		let scene = Scene()
		let board = scene.board
		let source = try #require(board.source(scene.source.id))

		let outline = board.outline(of: source)

		#expect(CanvasRegion.contains(scene.first.position, in: outline))
		#expect(CanvasRegion.contains(scene.second.position, in: outline))
		#expect(!CanvasRegion.contains(scene.outsider.position, in: outline))
	}

	@Test func arrangingPutsEachSourceBackAboveItsCards() throws {
		let scene = Scene()
		let store = BoardStore.test(scene.board)

		store.arrange()

		let source = try #require(store.source(scene.source.id))
		let cards = store.current.members(of: scene.source.id)
		#expect(cards.count == 2)
		#expect(source.position.y < cards.map(\.position.y).min() ?? 0)
	}
}
