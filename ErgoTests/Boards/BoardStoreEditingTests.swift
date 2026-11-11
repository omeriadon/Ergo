//
//  BoardStoreEditingTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

@testable import Ergo
import ErgoLogic
import Foundation
import SwiftUI
import Testing

/// Adding, changing, moving and deleting cards, drawing arrows between them, and laying them out
@Suite(.cleanDefaults)
struct BoardStoreEditingTests {
	// MARK: - Adding

	@Test func addingACardPutsAnEmptyOneWhereAsked() throws {
		let store = BoardStore.test(Board([card("Rain")]))

		let id = try #require(store.addStatement(at: CanvasPoint(x: 300, y: 400)))

		#expect(store.current.statements.count == 2)
		#expect(store.statement(id)?.position == CanvasPoint(x: 300, y: 400))
		#expect(store.statement(id)?.isEmpty == true)
	}

	@Test func aFullBoardTakesNoMoreCards() {
		let limit = ArgumentMapValidator.defaultMaximumStatements
		let full = Board((0 ..< limit).map { card("Claim \($0)", x: Double($0) * 300) })
		let store = BoardStore.test(full)

		#expect(store.addStatement(at: .zero) == nil)
		#expect(store.current.statements.count == limit)
	}

	// MARK: - Updating

	@Test func updatingACardChangesItsEnglish() {
		let rain = card("Rain")
		let store = BoardStore.test(Board([rain]))
		var edited = rain
		edited.english = "It rained."

		store.updateStatement(edited)

		#expect(store.statement(rain.id)?.english == "It rained.")
	}

	/// Typing goes through here on every keystroke, so a change to nothing mustn't count as an edit
	@Test func updatingACardToWhatItAlreadyIsChangesNothing() {
		let rain = card("Rain")
		let store = BoardStore.test(Board([rain]))
		let log = store.recordSaves()

		store.updateStatement(rain)
		store.save()

		#expect(log.saves.isEmpty)
	}

	@Test func updatingACardThatIsntThereChangesNothing() {
		let board = Board([card("Rain")])
		let store = BoardStore.test(board)

		store.updateStatement(card("Somewhere else"))

		#expect(store.current.statements == board.statements)
	}

	@Test func aBindingReadsAndWritesTheCardAndSurvivesItsDeletion() throws {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		let store = BoardStore.test(Board([rain, wet]))
		let binding = try #require(store.binding(for: rain.id))

		binding.wrappedValue.english = "It rained."
		#expect(store.statement(rain.id)?.english == "It rained.")

		// A view can still hold the binding after the card is gone. It mustn't crash, and a write goes nowhere.
		store.deleteStatement(id: rain.id)
		#expect(binding.wrappedValue.id == rain.id)
		binding.wrappedValue.english = "Written after it went"

		#expect(store.current.statements.map(\.id) == [wet.id])
		#expect(store.current.statements.map(\.english) == ["Wet"])
	}

	@Test func thereIsNoBindingForACardThatIsntThere() {
		let store = BoardStore.test(Board([card("Rain")]))

		#expect(store.binding(for: UUID()) == nil)
	}

	// MARK: - Moving

	@Test func movingACardSetsItsCentre() {
		let rain = card("Rain")
		let store = BoardStore.test(Board([rain]))

		store.moveStatement(id: rain.id, to: CanvasPoint(x: 500, y: 50))

		#expect(store.statement(rain.id)?.position == CanvasPoint(x: 500, y: 50))
	}

	@Test func movingACardToWhereItIsChangesNothing() {
		let rain = card("Rain", x: 10, y: 10)
		let store = BoardStore.test(Board([rain]))
		let log = store.recordSaves()

		store.moveStatement(id: rain.id, to: rain.position)
		store.save()

		#expect(log.saves.isEmpty)
	}

	// MARK: - Deleting

	@Test func deletingACardTakesItsArrowsAndOnlyThose() {
		let rain = card("Rain")
		let sun = card("Sun", x: 300)
		let wet = card("Wet", y: 200)
		let store = BoardStore.test(Board([rain, sun, wet], links: [arrow(rain, wet), arrow(sun, wet)]))

		store.deleteStatement(id: rain.id)

		#expect(store.current.statements.map(\.id) == [sun.id, wet.id])
		#expect(store.current.links.map(\.premise) == [sun.id])
	}

	@Test func deletingACardThatIsntThereChangesNothing() {
		let board = Board([card("Rain")])
		let store = BoardStore.test(board)
		let log = store.recordSaves()

		store.deleteStatement(id: UUID())
		store.save()

		#expect(store.current.statements == board.statements)
		#expect(log.saves.isEmpty)
	}

	/// A board is never without a card, so the last one is swapped for an empty one in the same place
	@Test func deletingTheLastCardLeavesAnEmptyOneInItsPlace() {
		let only = card("Only", x: 40, y: 80)
		let store = BoardStore.test(Board([only]))

		store.deleteStatement(id: only.id)

		#expect(store.current.statements.count == 1)
		#expect(store.current.statements.first?.isEmpty == true)
		#expect(store.current.statements.first?.position == only.position)
		#expect(store.current.statements.first?.id != only.id)
	}

	@Test func deletingTheLastCardNeedsNoSwapWhileASourceIsThere() {
		let only = card("Only")
		let store = BoardStore.test(Board([only], sources: [textSource()]))

		store.deleteStatement(id: only.id)

		#expect(store.current.statements.isEmpty)
		#expect(store.current.sources.count == 1)
	}

	// MARK: - Links

	@Test func anArrowJoinsAPremiseToAConclusion() {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		let store = BoardStore.test(Board([rain, wet]))

		let problem = store.link(premise: rain.id, conclusion: wet.id)

		#expect(problem == nil)
		#expect(store.current.links.map(\.premise) == [rain.id])
		#expect(store.current.links.map(\.conclusion) == [wet.id])
	}

	@Test func anArrowFromACardToItselfIsRefused() {
		let rain = card("Rain")
		let store = BoardStore.test(Board([rain]))

		let problem = store.link(premise: rain.id, conclusion: rain.id)

		guard case .selfLink? = problem else {
			Issue.record("Expected a link from a card to itself to be refused as a self link, found \(String(describing: problem))")
			return
		}
		#expect(store.current.links.isEmpty)
	}

	@Test func theSameArrowTwiceIsRefused() {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		let store = BoardStore.test(Board([rain, wet], links: [arrow(rain, wet)]))

		let problem = store.link(premise: rain.id, conclusion: wet.id)

		guard case .duplicateLink? = problem else {
			Issue.record("Expected the same arrow twice to be refused as a duplicate, found \(String(describing: problem))")
			return
		}
		#expect(store.current.links.count == 1)
	}

	@Test func anArrowThatLoopsBackIsRefused() {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		let store = BoardStore.test(Board([rain, wet], links: [arrow(rain, wet)]))

		let problem = store.link(premise: wet.id, conclusion: rain.id)

		guard case .cycle? = problem else {
			Issue.record("Expected an arrow back to its start to be refused as a cycle, found \(String(describing: problem))")
			return
		}
		#expect(store.current.links.count == 1)
	}

	@Test func anArrowToACardThatIsntThereIsRefused() {
		let rain = card("Rain")
		let store = BoardStore.test(Board([rain]))

		let problem = store.link(premise: rain.id, conclusion: UUID())

		guard case .danglingLink? = problem else {
			Issue.record("Expected an arrow to nowhere to be refused as dangling, found \(String(describing: problem))")
			return
		}
		#expect(store.current.links.isEmpty)
	}

	@Test func unlinkingRemovesTheArrowAndLeavesTheCards() {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		let link = arrow(rain, wet)
		let store = BoardStore.test(Board([rain, wet], links: [link]))

		store.unlink(id: link.id)

		#expect(store.current.links.isEmpty)
		#expect(store.current.statements.count == 2)
	}

	@Test func unlinkingAnArrowThatIsntThereChangesNothing() {
		let rain = card("Rain")
		let wet = card("Wet", y: 200)
		let store = BoardStore.test(Board([rain, wet], links: [arrow(rain, wet)]))
		let log = store.recordSaves()

		store.unlink(id: UUID())
		store.save()

		#expect(store.current.links.count == 1)
		#expect(log.saves.isEmpty)
	}

	// MARK: - Arranging

	@Test func arrangingPutsPremisesAboveTheirConclusionWithoutOverlap() throws {
		let rain = card("Rain")
		let wet = card("Wet")
		let store = BoardStore.test(Board([rain, wet], links: [arrow(rain, wet)]))

		store.arrange()

		let premise = try #require(store.statement(rain.id))
		let conclusion = try #require(store.statement(wet.id))
		#expect(premise.position.y < conclusion.position.y)
		let boxes = [premise, conclusion].map { CanvasRect(center: $0.position, size: CanvasLayout.boxSize) }
		#expect(!boxes[0].intersects(boxes[1]))
	}

	@Test func arrangingTwiceChangesNothingTheSecondTime() {
		let rain = card("Rain")
		let wet = card("Wet")
		let store = BoardStore.test(Board([rain, wet], links: [arrow(rain, wet)]))
		let log = store.recordSaves()

		store.arrange()
		store.save()
		store.arrange()
		store.save()

		#expect(log.saves.count == 1)
	}

	@Test func arrangingKeepsTheCardsAndArrows() {
		let rain = card("Rain")
		let wet = card("Wet")
		let link = arrow(rain, wet)
		let store = BoardStore.test(Board([rain, wet], links: [link]))

		store.arrange()

		#expect(Set(store.current.statements.map(\.id)) == [rain.id, wet.id])
		#expect(store.current.links == [link])
		#expect(store.current.statements.map(\.english) == ["Rain", "Wet"])
	}
}
