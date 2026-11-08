//
//  CanvasView+Editing.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoSync
import SwiftUI

extension CanvasView {
	// MARK: - Adding and deleting

	/// A new empty box where the person is looking
	func addStatement() {
		guard board.statements.count < ArgumentMapValidator.defaultMaximumStatements else {
			show(statementLimitMessage)
			return
		}

		history.perform("Add Statement") {
			withAnimation(motion) {
				selection = boardStore.addStatement(at: freeSpot(near: viewCentre)).map { .statement($0) }
			}
		}

		if keepsFitting, !canvasBoard.hasBeenMoved {
			fit(animated: true)
		}
		keepsFitting = false
	}

	var statementLimitMessage: String {
		"This board is full, it can only hold \(ArgumentMapValidator.defaultMaximumStatements) cards"
	}

	func delete(_ id: Statement.ID) {
		history.perform("Delete Statement") {
			withAnimation(motion) {
				boardStore.deleteStatement(id: id)
			}
		}
	}

	func deleteLink(_ id: Link.ID) {
		history.perform("Delete Link") {
			withAnimation(motion) {
				boardStore.unlink(id: id)
			}
		}
	}

	func arrange() {
		history.perform("Arrange") {
			withAnimation(motion) {
				boardStore.arrange()
			}
			canvasBoard.move(to: fitted, animation: motion)
		}
	}

	// MARK: - Notice

	func show(_ message: String) {
		notice = message
		AccessibilityNotification.Announcement(message).post()
	}

	// MARK: - Lifecycle

	var lifecycle: CanvasLifecycle {
		CanvasLifecycle(
			notice: notice,
			undoManager: undoManager,
			clearNotice: { notice = nil },
			wireHistory: wireHistory,
			refreshUndo: refreshUndo
		)
	}

	/// Keeps the whole board in view until the person moves the canvas or adds a box. The first measurements come in before
	/// the screen has finished laying out, so fitting only once would fit to the wrong room. Not while the editor is what
	/// changed the room.
	func fitUntilMoved() {
		guard keepsFitting, !canvasBoard.hasBeenMoved, !isCovered, room.viewport.width > 0, room.viewport.height > 0 else { return }
		fit(animated: false)
	}

	func wireHistory() {
		history.store = boardStore
		history.undoManager = undoManager
		history.didChange = refreshUndo
		refreshUndo()
	}

	func refreshUndo() {
		canUndo = undoManager?.canUndo ?? false
		canRedo = undoManager?.canRedo ?? false
	}
}
