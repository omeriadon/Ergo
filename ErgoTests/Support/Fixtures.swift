//
//  Fixtures.swift
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

// Small builders, so a test can say what it is about in a line. The stores read Defaults when they're made, so every
// test makes its own inside a suite marked `.cleanDefaults`.

extension BoardStore {
	/// A store holding `boards`, the first one open. Its delayed save is stopped when the test ends.
	static func test(_ boards: Board...) -> BoardStore {
		let store = BoardStore()
		store.boards = boards
		store.currentID = boards.first?.id
		TestDefaults.onFinish { store.saveTask?.cancel() }
		return store
	}

	/// What the store told sync, in order: the boards that changed and the ids deleted, for each save
	func recordSaves() -> SaveLog {
		let log = SaveLog()
		didSave = { changed, deleted in
			log.saves.append((changed, deleted))
		}
		return log
	}
}

/// Collects what a store reports on `didSave`
final class SaveLog {
	var saves: [(changed: [Board], deleted: Set<UUID>)] = []

	var changedIDs: Set<UUID> {
		Set(saves.flatMap(\.changed).map(\.id))
	}

	var deletedIDs: Set<UUID> {
		saves.reduce(into: []) { $0.formUnion($1.deleted) }
	}
}

extension ScratchpadStore {
	/// A store holding `scratchpads`. Its delayed save is stopped when the test ends.
	static func test(_ scratchpads: LogicScratchpad...) -> ScratchpadStore {
		Defaults[.scratchpads] = scratchpads
		Defaults[.currentScratchpadID] = scratchpads.first?.id
		let store = ScratchpadStore()
		TestDefaults.onFinish { store.save() }
		return store
	}
}

extension AskStore {
	/// A store that already holds `conversations`, as if they'd been saved by an earlier launch
	static func test(_ conversations: AskConversation...) -> AskStore {
		Defaults[.askConversations] = conversations
		return AskStore()
	}
}

// MARK: - Boards

/// A card at a place on the canvas
func card(_ english: String = "", x: Double = 0, y: Double = 0) -> Statement {
	Statement(position: CanvasPoint(x: x, y: y), english: english)
}

func arrow(_ premise: Statement, _ conclusion: Statement) -> Link {
	Link(premise: premise.id, conclusion: conclusion.id)
}

func textSource(_ text: String = "Some text.", x: Double = 0, y: Double = 0) -> BoardSource {
	BoardSource(position: CanvasPoint(x: x, y: y), content: .text(text))
}

extension Board {
	/// A board of exactly these cards, arrows and sources. Unlike `Board()` it has no empty card unless one is given.
	init(_ statements: [Statement], links: [Link] = [], sources: [BoardSource] = []) {
		self.init()
		self.statements = statements
		self.links = links
		self.sources = sources
	}
}

extension BoardShare {
	/// How a board the person was invited to looks to the store
	static func invited(to board: Board, as role: BoardRole) -> BoardShare {
		let owner = BoardMember(id: UUID(), name: "Ada", role: .owner)
		let me = BoardMember(id: UUID(), name: "Sam", role: role)
		return BoardShare(board: board.id.uuidString, role: role, member: me.id, members: [owner, me])
	}
}

// MARK: - Breakdowns

extension TranslateRequest {
	/// A breakdown request for this text, as the app would have sent it
	static func test(_ english: String) -> TranslateRequest {
		TranslateRequest(id: UUID(), english: english, provider: .claude, letters: LogicLetters.defaults, grammarVersion: 1)
	}
}

// MARK: - Logic

/// A scratchpad with some logic and the English it reads as
func scratchpad(_ logic: String, name: String = "") -> LogicScratchpad {
	var scratchpad = LogicScratchpad()
	scratchpad.name = name
	scratchpad.logic = Logic.entries(logic)
	scratchpad.english = Logic.reading(logic) ?? ""
	return scratchpad
}

enum Logic {
	/// What the logic keyboard would have typed for this text, with the default letters
	static func entries(_ text: String) -> [LogicKeyboardEntry] {
		LogicInputVocabulary(letters: LogicLetters.defaults).entries(in: text)
	}

	/// The English the Logic tab shows under this logic, which is what a scratchpad's `english` is kept as
	static func reading(_ text: String, descriptors: [String] = LogicLetters.emptyDescriptors) -> String? {
		LogicEnglish.text(for: LogicParser.parse(entries(text)), letters: LogicLetters.defaults, descriptors: descriptors)
	}
}
