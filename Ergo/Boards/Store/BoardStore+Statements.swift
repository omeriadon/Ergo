//
//  BoardStore+Statements.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import SwiftUI

extension BoardStore {
	// MARK: - statements

	/// The statement on the current board, nil once it's gone (deleted here or on another device)
	func statement(_ id: Statement.ID) -> Statement? {
		current.statement(id)
	}

	/// Reads and writes one statement of the current board. If the statement goes away while a view still holds the
	/// binding, reads give the last value it had and writes are dropped, so a view never crashes on a deleted box.
	func binding(for id: Statement.ID) -> Binding<Statement>? {
		guard let last = statement(id) else { return nil }
		return Binding(
			get: { [self] in statement(id) ?? last },
			set: { [self] in updateStatement($0) }
		)
	}

	/// Adds an empty statement with its centre at `position`, for the canvas dropping one where the person is looking.
	/// Nil when the board is full (`ArgumentMapValidator.defaultMaximumStatements`), or can only be viewed.
	@discardableResult
	func addStatement(at position: CanvasPoint) -> Statement.ID? {
		var board = current
		guard canEdit(board.id), board.statements.count < ArgumentMapValidator.defaultMaximumStatements else { return nil }

		var statement = Statement(position: position)
		statement.source = board.home(of: statement)
		board.statements.append(statement)
		current = board
		return statement.id
	}

	/// Replaces the statement with the same id. Typing goes through here, so one that changes nothing is skipped.
	func updateStatement(_ statement: Statement) {
		var board = current
		guard let index = board.statements.firstIndex(where: { $0.id == statement.id }), board.statements[index] != statement else { return }
		board.statements[index] = statement
		current = board
	}

	/// Sets the centre of the box, which can take it in or out of a region. Call it when a drag ends: sync writes the
	/// position as its own field, and every call restarts the save timer.
	func moveStatement(id: Statement.ID, to position: CanvasPoint) {
		var board = current
		guard let index = board.statements.firstIndex(where: { $0.id == id }), board.statements[index].position != position else { return }
		board.statements[index].position = position
		board.statements[index].source = board.home(of: board.statements[index])
		current = board
	}

	/// Deletes the statement and the links that touch it. The last statement is replaced with an empty one in the same
	/// place, since a board is never without one.
	func deleteStatement(id: Statement.ID) {
		var board = current
		guard let index = board.statements.firstIndex(where: { $0.id == id }) else { return }
		let position = board.statements[index].position
		board.statements.remove(at: index)
		board.links.removeAll { $0.premise == id || $0.conclusion == id }
		if board.statements.isEmpty, board.sources.isEmpty {
			board.statements = [Statement(position: position)]
		}
		current = board
	}

	// MARK: - links

	/// Draws an arrow from `premise` to `conclusion`. Nothing is added when it would be wrong (the same arrow twice,
	/// a statement to itself, a loop), and the reason comes back.
	@discardableResult
	func link(premise: Statement.ID, conclusion: Statement.ID) -> ArgumentMapProblem? {
		var board = current
		let link = Link(premise: premise, conclusion: conclusion)
		if let problem = ArgumentMapValidator.problem(adding: link, to: board.map) {
			return problem
		}
		board.links.append(link)
		current = board
		return nil
	}

	func unlink(id: Link.ID) {
		var board = current
		guard board.links.contains(where: { $0.id == id }) else { return }
		board.links.removeAll { $0.id == id }
		current = board
	}

	// MARK: - arranging

	/// Lays every statement out again (`CanvasLayout.arranged`)
	func arrange() {
		var board = current
		board.map = CanvasLayout.arranged(board.map)
		board.settleSources()
		guard board != current else { return }
		current = board
	}
}
