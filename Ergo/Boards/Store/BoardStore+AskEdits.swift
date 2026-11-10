//
//  BoardStore+AskEdits.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ErgoLogic
import ErgoProtocol
import Foundation

extension Board {
	/// The board written out, for attaching to a chat. A long source only goes in as far as it's likely to be read.
	var chatText: String {
		let cards = statements.compactMap(\.englishLine)
		let arrows = links.compactMap { link -> String? in
			guard let premise = statement(link.premise)?.englishLine, let conclusion = statement(link.conclusion)?.englishLine else { return nil }
			return "- “\(premise)” is a premise of “\(conclusion)”"
		}
		let notes = sources.map { source -> String in
			if case let .text(text) = source.content {
				return "- \(source.title): \(text.prefix(2000))"
			}
			return "- \(source.title)"
		}

		var parts = ["The board “\(title)”"]
		if !cards.isEmpty {
			parts.append("Cards:\n" + cards.map { "- \($0)" }.joined(separator: "\n"))
		}
		if !arrows.isEmpty {
			parts.append("Arrows:\n" + arrows.joined(separator: "\n"))
		}
		if !notes.isEmpty {
			parts.append("Sources:\n" + notes.joined(separator: "\n"))
		}
		return parts.joined(separator: "\n\n")
	}
}

/// What a chat about a board needs: the board as the model reads it, and the changes the model asks for
extension BoardStore {
	func board(_ id: Board.ID) -> Board? {
		current.id == id ? current : boards.first { $0.id == id }
	}

	/// How much of each source a chat sees, since it goes with every question and every question is counted
	private static let askSourceLimit = 8000

	/// The board as it goes to the model. A link's page isn't read for a chat, so the model only gets where it goes.
	func askBoard(_ id: Board.ID) -> AskBoard? {
		guard let board = board(id) else { return nil }
		let linked = Set(board.links.flatMap { [$0.premise, $0.conclusion] })
		return AskBoard(
			title: board.title,
			canEdit: canEdit(id),
			statements: board.statements
				.filter { linked.contains($0.id) || !$0.isEmpty }
				.map { .init(id: $0.id, english: $0.english) },
			links: board.links.map { .init(id: $0.id, premise: $0.premise, conclusion: $0.conclusion) },
			sources: board.sources.map { source in
				switch source.content {
					case let .text(text):
						.init(id: source.id, title: source.title, text: String(text.prefix(Self.askSourceLimit)))
					case let .link(url, _):
						.init(id: source.id, title: source.title, text: "A web link to \(url.absoluteString). Its page hasn't been read.")
				}
			}
		)
	}

	/// Changes a board whether or not it's the one on screen, since an answer can still be arriving after the person has
	/// moved on. Like `current`'s setter, it stops at a board this person can't edit.
	private func update(_ id: Board.ID, _ change: (inout Board) -> Bool) -> Bool {
		guard canEdit(id) else { return false }
		if current.id == id {
			var board = current
			guard change(&board) else { return false }
			current = board
			return true
		}
		guard let index = boards.firstIndex(where: { $0.id == id }), change(&boards[index]) else { return false }
		boards[index].modified = .now
		changedIDs.insert(id)
		scheduleSave()
		return true
	}

	/// Makes one change the model asked for. False when it can't be made: the board is gone or view only, a card it names
	/// is gone, the board is full, or the arrow would be wrong.
	@discardableResult
	func apply(_ change: AskBoardEdit.Change, to id: Board.ID) -> Bool {
		update(id) { board in
			switch change {
				case let .addCard(card, english, near):
					guard !board.statements.contains(where: { $0.id == card }) else { return true }
					// The empty card a new board starts with gives its place to the first real one
					if board.hasOnlyPlaceholder, let placeholder = board.statements.first {
						board.statements = [Statement(id: card, position: placeholder.position, english: english)]
						return true
					}
					guard board.statements.count < ArgumentMapValidator.defaultMaximumStatements else { return false }
					let occupied = board.statements.map(\.position) + board.sources.map(\.position)
					let anchor = near.flatMap { board.statement($0)?.position }
						?? board.statements.map(\.position).max { $0.y < $1.y }
						?? .zero
					// Beside what it's about, or under everything
					let position = CanvasLayout.place(near: anchor, side: near == nil ? .below : .beside, occupied: occupied)
					var statement = Statement(id: card, position: position, english: english)
					statement.source = board.home(of: statement)
					board.statements.append(statement)
					return true

				case let .editCard(card, english):
					guard let index = board.statements.firstIndex(where: { $0.id == card }) else { return false }
					board.statements[index].english = english
					return true

				case let .deleteCard(card):
					guard let index = board.statements.firstIndex(where: { $0.id == card }) else { return false }
					let position = board.statements[index].position
					board.statements.remove(at: index)
					board.links.removeAll { $0.premise == card || $0.conclusion == card }
					if board.statements.isEmpty, board.sources.isEmpty {
						board.statements = [Statement(position: position)]
					}
					return true

				case let .connect(premise, conclusion):
					let link = Link(premise: premise, conclusion: conclusion)
					guard ArgumentMapValidator.problem(adding: link, to: board.map) == nil else { return false }
					board.links.append(link)
					return true

				case let .disconnect(premise, conclusion):
					guard board.links.contains(where: { $0.premise == premise && $0.conclusion == conclusion }) else { return false }
					board.links.removeAll { $0.premise == premise && $0.conclusion == conclusion }
					return true
			}
		}
	}

	/// Puts a board back to how it was, for taking an answer's changes back. What's been typed since is lost with them.
	func restore(_ board: Board) {
		_ = update(board.id) { current in
			current.statements = board.statements
			current.links = board.links
			current.sources = board.sources
			return true
		}
	}
}
