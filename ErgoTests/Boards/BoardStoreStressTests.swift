//
//  BoardStoreStressTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 11/11/2026.
//

@testable import Ergo
import ErgoLogic
import ErgoProtocol
import ErgoSync
import Foundation
import Testing

/// Hundreds of edits in an order nobody would choose, with ids that are sometimes wrong. Whatever happens, the board
/// is still one the canvas can draw and sync can send. Each test takes a seed, so one that fails does so every time.
@Suite(.cleanDefaults)
struct BoardStoreStressTests {
	// MARK: - What must always be true

	/// A board the canvas can draw: something on it, arrows between cards that exist, no loops, and every card's
	/// region a source that's still there
	static func expectWhole(_ board: Board, _ step: String, regions: Bool = true) {
		#expect(!board.statements.isEmpty || !board.sources.isEmpty, "Expected something on the board after \(step)")
		let problems = ArgumentMapValidator.validate(board.map)
		#expect(problems.isEmpty, "Expected a valid map after \(step), found \(problems)")

		let sources = Set(board.sources.map(\.id))
		#expect(sources.count == board.sources.count, "Expected every source once after \(step)")
		for statement in board.statements {
			if regions, let source = statement.source {
				#expect(sources.contains(source), "Expected a card's region to be a source on the board after \(step)")
			}
			#expect(statement.position.x.isFinite && statement.position.y.isFinite, "Expected a card with a place after \(step)")
		}
	}

	// MARK: - Random edits

	static func point(_ random: inout SeededRandom) -> CanvasPoint {
		CanvasPoint(x: Double(Int.random(in: -40 ... 40, using: &random) * 20), y: Double(Int.random(in: -40 ... 40, using: &random) * 20))
	}

	static let sentences = ["It rained.", "The ground is wet.", "", "   ", "Puddles formed.", String(repeating: "A long claim. ", count: 200), "👨‍👩‍👧 é \u{0}"]

	/// One edit through the store, the way the canvas and the editor make them. Ids are sometimes ones the board never had.
	static func edit(_ store: BoardStore, _ random: inout SeededRandom) -> String {
		let board = store.current
		let card = random.chance(8) ? UUID() : board.statements.randomElement(using: &random)?.id ?? UUID()
		let other = random.chance(8) ? UUID() : board.statements.randomElement(using: &random)?.id ?? UUID()
		let source = random.chance(8) ? UUID() : board.sources.randomElement(using: &random)?.id ?? UUID()

		switch Int.random(in: 0 ..< 14, using: &random) {
			case 0, 1:
				store.addStatement(at: point(&random))
				return "adding a card"
			case 2:
				guard var statement = board.statement(card) else { return "nothing" }
				statement.english = sentences.randomElement(using: &random)!
				store.updateStatement(statement)
				return "typing in a card"
			case 3:
				// A card the editor still holds after it was deleted
				store.updateStatement(Statement(id: card, position: point(&random), english: "Stale."))
				return "updating a card"
			case 4:
				store.moveStatement(id: card, to: point(&random))
				return "moving a card"
			case 5:
				store.deleteStatement(id: card)
				return "deleting a card"
			case 6, 7, 8:
				store.link(premise: card, conclusion: other)
				return "drawing an arrow"
			case 9:
				store.unlink(id: random.chance(5) ? UUID() : board.links.randomElement(using: &random)?.id ?? UUID())
				return "removing an arrow"
			case 10:
				store.addSource(.text(sentences.randomElement(using: &random)!), at: point(&random))
				return "adding a source"
			case 11:
				store.moveSource(id: source, to: point(&random))
				return "moving a source"
			case 12:
				store.deleteSource(id: source)
				return "deleting a source"
			default:
				store.arrange()
				return "arranging"
		}
	}

	@Test(arguments: 0 ..< 60 as Range<UInt64>)
	func whateverIsDoneTheBoardStaysWhole(seed: UInt64) {
		var random = SeededRandom(seed: seed)
		let store = BoardStore.test(Board([card("It rained.")]))

		for _ in 0 ..< 200 {
			let step = Self.edit(store, &random)
			Self.expectWhole(store.current, step)
		}

		#expect(store.boards.count == 1, "Expected edits to stay on the one board")
	}

	@Test(arguments: 100 ..< 110 as Range<UInt64>)
	func aFullBoardTakesNoMoreCards(seed: UInt64) {
		var random = SeededRandom(seed: seed)
		let store = BoardStore.test(Board([card("It rained.")]))

		for _ in 0 ..< ArgumentMapValidator.defaultMaximumStatements * 2 {
			store.addStatement(at: Self.point(&random))
		}

		#expect(store.current.statements.count == ArgumentMapValidator.defaultMaximumStatements)
		#expect(store.addStatement(at: .zero) == nil)
		Self.expectWhole(store.current, "filling the board")
	}

	// MARK: - A board that can only be viewed

	@Test(arguments: 200 ..< 230 as Range<UInt64>)
	func aViewerChangesNothingWhateverTheyTry(seed: UInt64) throws {
		var random = SeededRandom(seed: seed)
		let rain = card("It rained.", y: 0)
		let wet = card("The ground is wet.", y: 200)
		let slippery = card("The path is slippery.", y: 400)
		let board = Board([rain, wet, slippery], links: [arrow(rain, wet)], sources: [textSource("The article.", x: 400)])
		let store = BoardStore.test(board)
		store.shares[board.id] = .invited(to: board, as: .viewer)
		let log = store.recordSaves()

		for _ in 0 ..< 120 {
			_ = Self.edit(store, &random)
			let change: AskBoardEdit.Change = try #require([
				.addCard(id: UUID(), english: "Puddles formed.", near: rain.id),
				.editCard(id: rain.id, english: "It poured."),
				.deleteCard(id: wet.id),
				.connect(premise: wet.id, conclusion: slippery.id),
				.disconnect(premise: rain.id, conclusion: wet.id),
			].randomElement(using: &random))
			#expect(!store.apply(change, to: board.id))
		}
		store.rename(board.id, to: "Mine now")
		store.save()

		#expect(store.current.statements == board.statements)
		#expect(store.current.links == board.links)
		#expect(store.current.sources == board.sources)
		#expect(store.current.name == board.name)
		#expect(log.changedIDs.isEmpty)
		#expect(log.deletedIDs.isEmpty)
	}

	// MARK: - What a chat asks for

	@Test(arguments: 300 ..< 340 as Range<UInt64>)
	func whateverAChatAsksTheBoardStaysWhole(seed: UInt64) throws {
		var random = SeededRandom(seed: seed)
		let open = Board([card("It rained.")])
		let elsewhere = Board([card("Another board.")])
		let store = BoardStore.test(open, elsewhere)

		for _ in 0 ..< 200 {
			// An answer can still be arriving for a board that isn't on screen
			let target = random.chance(3) ? elsewhere.id : open.id
			guard let board = store.board(target) else {
				Issue.record("Expected both boards to last")
				return
			}
			func id() -> UUID {
				random.chance(6) ? UUID() : board.statements.randomElement(using: &random)?.id ?? UUID()
			}
			let change: AskBoardEdit.Change = switch Int.random(in: 0 ..< 8, using: &random) {
				case 0, 1: try .addCard(id: random.chance(10) ? id() : UUID(), english: #require(Self.sentences.randomElement(using: &random)), near: random.chance(2) ? id() : nil)
				case 2: try .editCard(id: id(), english: #require(Self.sentences.randomElement(using: &random)))
				case 3: .deleteCard(id: id())
				case 4, 5, 6: .connect(premise: id(), conclusion: id())
				default: .disconnect(premise: id(), conclusion: id())
			}

			store.apply(change, to: target)

			for id in [open.id, elsewhere.id] {
				if let board = store.board(id) {
					Self.expectWhole(board, "\(change)")
				}
			}
		}
	}

	@Test(arguments: 400 ..< 420 as Range<UInt64>)
	func takingAnAnswerBackGivesTheBoardItStartedWith(seed: UInt64) {
		var random = SeededRandom(seed: seed)
		let store = BoardStore.test(Board([card("It rained.")]))
		for _ in 0 ..< 40 {
			_ = Self.edit(store, &random)
		}
		let before = store.current

		for _ in 0 ..< 40 {
			_ = Self.edit(store, &random)
		}
		store.restore(before)

		#expect(store.current.statements == before.statements)
		#expect(store.current.links == before.links)
		#expect(store.current.sources == before.sources)
	}

	// MARK: - To sync and back

	@Test(arguments: 500 ..< 540 as Range<UInt64>)
	func anyBoardComesBackFromItsRecords(seed: UInt64) throws {
		var random = SeededRandom(seed: seed)
		let store = BoardStore.test(Board([card("It rained.")]))
		for _ in 0 ..< 150 {
			_ = Self.edit(store, &random)
		}
		var board = store.current
		board.name = try #require(["", "Weather", "👨‍👩‍👧", String(repeating: "long ", count: 100)].randomElement(using: &random))

		let replica = try SyncReplica.holding(board)
		let rebuilt = BoardRecord.rebuild([board.id], from: replica, local: [])

		let back = try #require(rebuilt.boards.first)
		#expect(rebuilt.deleted.isEmpty)
		#expect(back.id == board.id)
		#expect(back.name == board.name)
		#expect(Set(back.statements) == Set(board.statements))
		#expect(back.statements.count == board.statements.count)
		#expect(Set(back.links) == Set(board.links))
		#expect(Set(back.sources) == Set(board.sources))
		Self.expectWhole(back, "coming back from records")

		// Building on what's here already changes nothing, in the order it was in
		let again = try #require(BoardRecord.rebuild([board.id], from: replica, local: [board]).boards.first)
		#expect(again.statements == board.statements)
		#expect(again.sources == board.sources)
		#expect(Set(again.links) == Set(board.links))
	}

	/// Records can arrive in any order and some never arrive, so whatever part of a board is here has to stand up
	@Test(arguments: 600 ..< 640 as Range<UInt64>)
	func aBoardWithRecordsMissingIsStillWhole(seed: UInt64) throws {
		var random = SeededRandom(seed: seed)
		let store = BoardStore.test(Board([card("It rained.")]))
		for _ in 0 ..< 150 {
			_ = Self.edit(store, &random)
		}
		let board = store.current
		var replica = try SyncReplica.holding(board)
		for key in replica.records.keys.sorted() where key.kind != .board && random.chance(3) {
			replica = replica.without(key)
		}

		let rebuilt = BoardRecord.rebuild([board.id], from: replica, local: [])

		let back = try #require(rebuilt.boards.first)
		// A card's source may be one of the records still to come
		Self.expectWhole(back, "losing some records", regions: false)
		#expect(Set(back.statements.map(\.id)).subtracting(board.statements.map(\.id)).count <= 1, "Expected no cards from nowhere but an empty one")
		#expect(Set(back.links).isSubset(of: Set(board.links)))
	}
}
