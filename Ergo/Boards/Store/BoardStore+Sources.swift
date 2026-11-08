//
//  BoardStore+Sources.swift
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
	// MARK: - sources

	func source(_ id: BoardSource.ID) -> BoardSource? {
		current.source(id)
	}

	/// A new source at `position`, in place of the empty card a new board starts with
	@discardableResult
	func addSource(_ content: BoardSource.Content, at position: CanvasPoint) -> BoardSource.ID {
		var board = current
		if board.hasOnlyPlaceholder {
			board.statements = []
		}
		let source = BoardSource(position: position, content: content)
		board.sources.append(source)
		current = board
		return source.id
	}

	/// A new source under everything on the board, for when nobody's looking at the canvas to say where
	func addSource(_ content: BoardSource.Content) {
		let board = current
		let rects = board.hasOnlyPlaceholder ? board.sources.map { CanvasRect.box(at: $0.position) } : board.occupiedRects
		let position = if let left = rects.map(\.minX).min(), let bottom = rects.map(\.maxY).max() {
			CanvasGrid.snapped(CanvasPoint(x: left + CanvasLayout.boxSize.width / 2, y: bottom + CanvasLayout.rowGap))
		} else {
			CanvasPoint.zero
		}
		addSource(content, at: position)
	}

	func updateSource(_ id: BoardSource.ID, content: BoardSource.Content) {
		var board = current
		guard let index = board.sources.firstIndex(where: { $0.id == id }), board.sources[index].content != content else { return }
		board.sources[index].content = content
		current = board
	}

	/// Moves the source and its cards together, so the region keeps its shape
	func moveSource(id: BoardSource.ID, to position: CanvasPoint) {
		var board = current
		guard let index = board.sources.firstIndex(where: { $0.id == id }), board.sources[index].position != position else { return }
		let travel = position - board.sources[index].position
		board.sources[index].position = position
		for card in board.statements.indices where board.statements[card].source == id {
			board.statements[card].position = board.statements[card].position + travel
		}
		current = board
	}

	/// The cards stay, without the region around them. A board never ends up with nothing on it.
	func deleteSource(id: BoardSource.ID) {
		var board = current
		guard let index = board.sources.firstIndex(where: { $0.id == id }) else { return }
		let position = board.sources[index].position
		board.sources.remove(at: index)
		for card in board.statements.indices where board.statements[card].source == id {
			board.statements[card].source = nil
		}
		if board.statements.isEmpty, board.sources.isEmpty {
			board.statements = [Statement(position: position)]
		}
		current = board
	}
}
