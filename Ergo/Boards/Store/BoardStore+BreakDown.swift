//
//  BoardStore+BreakDown.swift
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
	// MARK: - breaking down

	/// Opens a new board holding a server breakdown: a statement per premise and one for the conclusion, every premise linked
	/// to it (`ArgumentBreakdown.applied`), all in a region on `content`, which is what was broken down. The breakdown's
	/// claims are dropped, since a board holds English only. Statements past the limit are left out.
	func newBoard(from breakdown: ArgumentBreakdown, source content: BoardSource.Content) {
		newBoard()

		var board = current
		let source = BoardSource(position: .zero, content: content)
		board.sources = [source]
		put(breakdown, into: &board, from: source.id)
		current = board
	}

	/// Puts a breakdown of one of the current board's sources under everything on the board, and moves the source onto it.
	/// Nothing already there moves.
	func breakDown(_ breakdown: ArgumentBreakdown, into source: BoardSource.ID) {
		var board = current
		put(breakdown, into: &board, from: source)
		current = board
	}

	func put(_ breakdown: ArgumentBreakdown, into board: inout Board, from source: BoardSource.ID) {
		let application = breakdown.applied(to: board.map, replacing: board.hasOnlyPlaceholder)
		board.map = application.map

		// `applied` only knows about statements, so it's kept clear of other sources here
		let added = Set(application.added)
		let top = board.statements.filter { added.contains($0.id) }.map(\.position.y).min() ?? 0
		let room = CanvasRegion.padding + CanvasLayout.boxSize.height * 2 + CanvasLayout.rowGap
		let lowest = board.sources.filter { $0.id != source }.map(\.position.y).max()
		let shift = lowest.map { max($0 + room - top, 0) } ?? 0

		for index in board.statements.indices where added.contains(board.statements[index].id) {
			board.statements[index].position.y += shift
			board.statements[index].source = source
		}

		let cards = board.members(of: source).map(\.position)
		if let position = CanvasRegion.sourcePosition(above: cards), let index = board.sources.firstIndex(where: { $0.id == source }) {
			board.sources[index].position = position
		}
	}
}
