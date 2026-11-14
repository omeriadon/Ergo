//
//  BoardStore+Templates.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import ErgoLogic
import SwiftUI

extension BoardStore {
	// MARK: - templates

	/// Opens a new board in the shape of `template`: its cards laid out and linked, each empty with the template's prompt
	/// as its placeholder. It's a draft like any new board, so it stays out of the list until something's written on it.
	func newBoard(from template: BoardTemplate) {
		newBoard()
		guard template != .blank else { return }

		var board = draft
		let placeholders = template.apply(to: &board.map)
		for index in board.statements.indices {
			board.statements[index].placeholder = placeholders[board.statements[index].id]
		}
		draft = board
	}
}
