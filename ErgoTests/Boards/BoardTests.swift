//
//  BoardTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

@testable import Ergo
import ErgoLogic
import Foundation
import Testing

/// The board value itself: what makes it empty, what it's called, and its map
struct BoardTests {
	// MARK: - Empty

	@Test func aNewBoardIsEmptyButHasOneCardToWriteOn() {
		let board = Board()

		#expect(board.isEmpty)
		#expect(board.statements.count == 1)
		#expect(board.hasOnlyPlaceholder)
	}

	@Test func writingOnACardMakesTheBoardNotEmpty() {
		#expect(!Board([card("It rained.")]).isEmpty)
	}

	@Test func anArrowMeansSomethingWasDoneEvenBetweenEmptyCards() {
		let first = card()
		let second = card(y: 200)

		#expect(!Board([first, second], links: [arrow(first, second)]).isEmpty)
	}

	@Test func aTemplatesArrowsBetweenItsEmptyCardsLeaveTheBoardEmpty() {
		var first = card()
		first.placeholder = "A reason for it"
		var second = card(y: 200)
		second.placeholder = "The claim you're testing"

		#expect(Board([first, second], links: [arrow(first, second)]).isEmpty)
	}

	@Test func aSourceAloneMakesTheBoardNotEmpty() {
		let board = Board([], sources: [textSource()])

		#expect(!board.isEmpty)
	}

	@Test func moreEmptyCardsStillLeaveTheBoardEmpty() {
		#expect(Board([card(), card(x: 300), card(x: 600)]).isEmpty)
	}

	@Test func aCardOfOnlySpacesIsEmpty() {
		#expect(Board([card("  \n ")]).isEmpty)
	}

	// MARK: - Title

	@Test func aNameWinsOverWhatIsWritten() {
		var board = Board([card("It rained.")])
		board.name = "Weather"

		#expect(board.title == "Weather")
	}

	@Test func withoutANameTheTitleIsTheFirstCardInReadingOrder() {
		let conclusion = card("The ground is wet.")
		let premise = card("It rained.", y: 200)
		let board = Board([conclusion, premise], links: [arrow(premise, conclusion)])

		#expect(board.title == "It rained.")
	}

	@Test func theTitleIsOnlyTheFirstLineOfACard() {
		#expect(Board([card("It rained.\nAnd rained.")]).title == "It rained.")
	}

	@Test func aBoardOfOnlyASourceIsTitledFromIt() {
		let board = Board([], sources: [textSource("The forecast.\nMore of it.")])

		#expect(board.title == "The forecast.")
	}

	@Test func aBoardWithNothingWrittenIsUntitled() {
		#expect(Board().title == "Untitled")
	}

	// MARK: - Map

	@Test func theMapHoldsTheCardsAndArrows() {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		let link = arrow(rain, wet)
		let board = Board([rain, wet], links: [link])

		#expect(board.map.statements == [rain, wet])
		#expect(board.map.links == [link])
	}

	@Test func changingTheMapChangesTheBoardsCardsAndArrows() {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		var board = Board([rain])

		var map = board.map
		map.statements.append(wet)
		map.links.append(arrow(rain, wet))
		board.map = map

		#expect(board.statements == [rain, wet])
		#expect(board.links.count == 1)
	}

	@Test func changingTheMapLeavesSourcesAlone() {
		let source = textSource()
		var board = Board([card("Rain")], sources: [source])

		board.map = ArgumentMap(statements: [card("Other")], links: [])

		#expect(board.sources == [source])
	}

	// MARK: - Lookups

	@Test func cardsAndSourcesAreFoundById() {
		let rain = card("Rain")
		let source = textSource()
		let board = Board([rain], sources: [source])

		#expect(board.statement(rain.id) == rain)
		#expect(board.source(source.id) == source)
		#expect(board.statement(UUID()) == nil)
		#expect(board.source(UUID()) == nil)
	}

	// MARK: - Writing it out

	@Test func aBoardIsWrittenOutForAChat() {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		var board = Board([rain, wet], links: [arrow(rain, wet)], sources: [textSource("The forecast.")])
		board.name = "Weather"

		#expect(board.chatText == """
		The board “Weather”

		Cards:
		- Rain
		- Wet

		Arrows:
		- “Rain” is a premise of “Wet”

		Sources:
		- The forecast.: The forecast.
		""")
	}

	@Test func aBoardWithNoArrowsOrSourcesLeavesThoseOut() {
		let text = Board([card("Rain")]).chatText

		#expect(!text.contains("Arrows:"))
		#expect(!text.contains("Sources:"))
	}
}
