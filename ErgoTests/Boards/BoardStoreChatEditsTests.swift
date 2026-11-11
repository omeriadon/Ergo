//
//  BoardStoreChatEditsTests.swift
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

/// What a chat about a board sees of it, and the changes the model asks for
@Suite(.cleanDefaults)
struct BoardStoreChatEditsTests {
	let rain = card("Rain")
	let wet = card("Wet", y: 200)

	// MARK: - Adding

	@Test func aNewCardTakesThePlaceOfTheEmptyStartingCard() {
		let blank = Board()
		let store = BoardStore.test(blank)
		let id = UUID()

		let made = store.apply(.addCard(id: id, english: "It rained.", near: nil), to: blank.id)

		#expect(made)
		#expect(store.current.statements.count == 1)
		#expect(store.statement(id)?.english == "It rained.")
		#expect(store.statement(id)?.position == blank.statements[0].position)
	}

	@Test func aNewCardGoesBesideTheOneItIsAbout() throws {
		let store = BoardStore.test(Board([rain, wet]))
		let id = UUID()

		let made = store.apply(.addCard(id: id, english: "Sun", near: rain.id), to: store.current.id)

		#expect(made)
		let added = try #require(store.statement(id))
		#expect(added.position.x > rain.position.x)
		let box = CanvasRect(center: added.position, size: CanvasLayout.boxSize)
		for other in [rain, wet] {
			#expect(!box.intersects(CanvasRect(center: other.position, size: CanvasLayout.boxSize)))
		}
	}

	@Test func aNewCardAboutNothingGoesUnderEverything() throws {
		let store = BoardStore.test(Board([rain, wet]))
		let id = UUID()

		store.apply(.addCard(id: id, english: "Sun", near: nil), to: store.current.id)

		let added = try #require(store.statement(id))
		#expect(added.position.y > wet.position.y)
	}

	/// An answer heard again from the start says the same thing, and a card is only made once
	@Test func addingTheSameCardTwiceMakesItOnce() {
		let store = BoardStore.test(Board([rain, wet]))
		let id = UUID()

		store.apply(.addCard(id: id, english: "Sun", near: nil), to: store.current.id)
		let again = store.apply(.addCard(id: id, english: "Sun", near: nil), to: store.current.id)

		#expect(again)
		#expect(store.current.statements.count == 3)
	}

	@Test func aFullBoardRefusesAnotherCard() {
		let limit = ArgumentMapValidator.defaultMaximumStatements
		let store = BoardStore.test(Board((0 ..< limit).map { card("Claim \($0)", x: Double($0) * 300) }))

		let made = store.apply(.addCard(id: UUID(), english: "One too many", near: nil), to: store.current.id)

		#expect(!made)
		#expect(store.current.statements.count == limit)
	}

	// MARK: - Changing

	@Test func editingACardChangesItsEnglish() {
		let store = BoardStore.test(Board([rain, wet]))

		let made = store.apply(.editCard(id: rain.id, english: "It poured."), to: store.current.id)

		#expect(made)
		#expect(store.statement(rain.id)?.english == "It poured.")
	}

	@Test func editingACardThatIsGoneFails() {
		let store = BoardStore.test(Board([rain, wet]))

		let made = store.apply(.editCard(id: UUID(), english: "Nothing"), to: store.current.id)

		#expect(!made)
	}

	@Test func deletingACardTakesItsArrows() {
		let sun = card("Sun", x: 300)
		let store = BoardStore.test(Board([rain, sun, wet], links: [arrow(rain, wet), arrow(sun, wet)]))

		let made = store.apply(.deleteCard(id: rain.id), to: store.current.id)

		#expect(made)
		#expect(store.current.statements.map(\.id) == [sun.id, wet.id])
		#expect(store.current.links.map(\.premise) == [sun.id])
	}

	@Test func deletingTheLastCardLeavesAnEmptyOne() {
		let store = BoardStore.test(Board([rain]))

		store.apply(.deleteCard(id: rain.id), to: store.current.id)

		#expect(store.current.statements.count == 1)
		#expect(store.current.statements.first?.isEmpty == true)
	}

	@Test func connectingAndDisconnectingMakesAndRemovesAnArrow() {
		let store = BoardStore.test(Board([rain, wet]))
		let id = store.current.id

		#expect(store.apply(.connect(premise: rain.id, conclusion: wet.id), to: id))
		#expect(store.current.links.count == 1)

		#expect(store.apply(.disconnect(premise: rain.id, conclusion: wet.id), to: id))
		#expect(store.current.links.isEmpty)
	}

	@Test func anArrowThatWouldLoopFails() {
		let store = BoardStore.test(Board([rain, wet], links: [arrow(rain, wet)]))

		let made = store.apply(.connect(premise: wet.id, conclusion: rain.id), to: store.current.id)

		#expect(!made)
		#expect(store.current.links.count == 1)
	}

	@Test func removingAnArrowThatIsntThereFails() {
		let store = BoardStore.test(Board([rain, wet]))

		let made = store.apply(.disconnect(premise: rain.id, conclusion: wet.id), to: store.current.id)

		#expect(!made)
	}

	// MARK: - Which board

	@Test func aViewOnlyBoardIsNotChanged() {
		let board = Board([rain, wet])
		let store = BoardStore.test(board)
		store.shares[board.id] = .invited(to: board, as: .viewer)

		let made = store.apply(.editCard(id: rain.id, english: "Changed"), to: board.id)

		#expect(!made)
		#expect(store.current == board)
	}

	@Test func aBoardThatIsGoneIsNotChanged() {
		let store = BoardStore.test(Board([rain]))

		let made = store.apply(.editCard(id: rain.id, english: "Changed"), to: UUID())

		#expect(!made)
	}

	/// An answer can still be arriving after the person has opened another board
	@Test func aBoardThatIsntOpenIsChangedAndReported() {
		let open = Board([card("Open")])
		let other = Board([rain, wet])
		let store = BoardStore.test(open, other)
		let log = store.recordSaves()

		let made = store.apply(.editCard(id: rain.id, english: "It poured."), to: other.id)
		store.save()

		#expect(made)
		#expect(store.board(other.id)?.statement(rain.id)?.english == "It poured.")
		#expect(store.current == open)
		#expect(log.changedIDs == [other.id])
	}

	@Test func restoringPutsTheCardsBackAsTheyWere() {
		let before = Board([rain, wet], links: [arrow(rain, wet)])
		let store = BoardStore.test(before)
		store.apply(.deleteCard(id: rain.id), to: before.id)
		store.apply(.addCard(id: UUID(), english: "Another", near: nil), to: before.id)

		store.restore(before)

		#expect(store.current.statements == before.statements)
		#expect(store.current.links == before.links)
	}

	// MARK: - What the model sees

	@Test func theModelSeesWrittenCardsAndLeavesOutEmptyOnes() throws {
		let blank = card("", x: 300)
		let store = BoardStore.test(Board([rain, blank, wet]))

		let seen = try #require(store.askBoard(store.current.id))

		#expect(seen.statements.map(\.english) == ["Rain", "Wet"])
	}

	@Test func anEmptyCardWithAnArrowIsStillSeen() throws {
		let blank = card("", x: 300)
		let store = BoardStore.test(Board([rain, blank], links: [arrow(blank, rain)]))

		let seen = try #require(store.askBoard(store.current.id))

		#expect(seen.statements.count == 2)
		#expect(seen.links.count == 1)
	}

	@Test func theModelIsToldWhetherItMayChangeTheBoard() throws {
		let board = Board([rain])
		let store = BoardStore.test(board)
		let beforeSharing = try #require(store.askBoard(board.id))

		store.shares[board.id] = .invited(to: board, as: .viewer)
		let asViewer = try #require(store.askBoard(board.id))

		#expect(beforeSharing.canEdit)
		#expect(!asViewer.canEdit)
	}

	@Test func aLongSourceIsCutAndALinkIsOnlyWhereItGoes() throws {
		let long = textSource(String(repeating: "x", count: 20000))
		let link = try BoardSource(position: .zero, content: .link(#require(URL(string: "https://example.com/page")), title: "Page"))
		let store = BoardStore.test(Board([rain], sources: [long, link]))

		let seen = try #require(store.askBoard(store.current.id))

		#expect(seen.sources[0].text.count == 8000)
		#expect(seen.sources[1].text.contains("https://example.com/page"))
		#expect(seen.sources[1].text.contains("hasn't been read"))
	}

	@Test func aBoardThatIsntThereIsNotSeen() {
		let store = BoardStore.test(Board([rain]))

		#expect(store.askBoard(UUID()) == nil)
	}
}
