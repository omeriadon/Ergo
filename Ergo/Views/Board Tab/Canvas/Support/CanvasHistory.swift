//
//  CanvasHistory.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// Undo and redo for the canvas, one step per drag, delete, link, add or arrange, through the window's `UndoManager`
/// so shake to undo works too.
///
/// A step is a snapshot of the statements, links and sources from before the change. Going back to it puts back positions,
/// links, regions, and what was deleted, but keeps the words of what's still there, so undoing a move never throws away
/// what was typed in the editor since.
@MainActor
final class CanvasHistory {
	struct Snapshot: Equatable, Sendable {
		let boardID: Board.ID
		let statements: [Statement]
		let links: [Link]
		let sources: [BoardSource]
	}

	var undoManager: UndoManager?
	weak var store: BoardStore?

	/// Told after every register, undo and redo, so the menu can enable or disable its items
	var didChange: (() -> Void)?

	func snapshot() -> Snapshot? {
		guard let board = store?.current else { return nil }
		return Snapshot(boardID: board.id, statements: board.statements, links: board.links, sources: board.sources)
	}

	/// Runs `change` and makes it one undo step, if it changed anything
	func perform(_ name: String, _ change: () -> Void) {
		let before = snapshot()
		change()
		register(before, name: name)
	}

	/// Makes everything since `before` one undo step. Nothing is registered when nothing changed.
	func register(_ before: Snapshot?, name: String) {
		guard let before, let now = snapshot(), now != before else { return }
		undoManager?.registerUndo(withTarget: self) { history in
			MainActor.assumeIsolated {
				history.restore(before, name: name)
			}
		}
		undoManager?.setActionName(name)
		didChange?()
	}

	/// Forgets every step, for a board that's gone from the screen. Their snapshots are of the old board.
	func clear() {
		undoManager?.removeAllActions(withTarget: self)
		didChange?()
	}

	private func restore(_ snapshot: Snapshot, name: String) {
		// Steps from before someone's role changed to View only, and shake to undo can still reach them
		guard let store, store.canEdit(snapshot.boardID), store.current.id == snapshot.boardID, let now = self.snapshot() else { return }

		var board = store.current
		board.statements = snapshot.statements.map { old in
			guard var kept = board.statements.first(where: { $0.id == old.id }) else { return old }
			kept.position = old.position
			kept.source = old.source
			return kept
		}
		board.links = snapshot.links
		board.sources = snapshot.sources.map { old in
			guard var kept = board.source(old.id) else { return old }
			kept.position = old.position
			return kept
		}
		store.current = board

		// Registered while undoing, so the manager files it as the redo (and the other way round)
		undoManager?.registerUndo(withTarget: self) { history in
			MainActor.assumeIsolated {
				history.restore(now, name: name)
			}
		}
		undoManager?.setActionName(name)
		didChange?()
	}
}

extension EnvironmentValues {
	/// The wide layout's history, which outlives the Board section's views so leaving the section keeps the undo steps.
	/// Nil in the narrow layout, where the Board tab is never torn down and keeps its own.
	@Entry var canvasHistory: CanvasHistory?
}
