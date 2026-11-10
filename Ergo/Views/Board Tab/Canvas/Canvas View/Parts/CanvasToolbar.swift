//
//  CanvasToolbar.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoSync
import SwiftUI

/// Fit, Quick AI, what the analysis found, Boards, and a menu for the rest
struct CanvasToolbar: ToolbarContent {
	let board: Board
	let isReadOnly: Bool
	let isAnalysing: Bool

	/// A deep research run is going, or one has left results to open
	let hasAnalysis: Bool
	let canUndo: Bool
	let canRedo: Bool
	let fit: () -> Void
	let showBoards: () -> Void
	let search: () -> Void
	let quickAI: () -> Void
	let showAnalysis: () -> Void
	let deepResearch: () -> Void
	let sendToChat: () -> Void
	let undo: () -> Void
	let redo: () -> Void
	let arrange: () -> Void

	var body: some ToolbarContent {
		ToolbarItemGroup(placement: .topBarTrailing) {
			Button("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass", action: fit)
				.accessibilityIdentifier("board.fitButton")

			Button("Quick AI", systemImage: "sparkles", action: quickAI)
				.accessibilityIdentifier("board.quickAI")

			// Not on a board this person can only view. They still see the annotations.
			if !isReadOnly, hasAnalysis {
				AnalyseButton(isAnalysing: isAnalysing, analyse: showAnalysis)
			}

			Button("Boards", systemImage: "text.page.and.line.vertical.and.text.page", action: showBoards)
				.accessibilityIdentifier("board.boardsButton")
		}

		ToolbarOverflowMenu {
			CanvasMenuContent(
				board: board,
				isReadOnly: isReadOnly,
				isAnalysing: isAnalysing,
				canUndo: canUndo,
				canRedo: canRedo,
				search: search,
				deepResearch: deepResearch,
				sendToChat: sendToChat,
				undo: undo,
				redo: redo,
				arrange: arrange
			)
		}
	}
}

private struct AnalyseButton: View {
	let isAnalysing: Bool
	let analyse: () -> Void

	var body: some View {
		Button(action: analyse) {
			if isAnalysing {
				ProgressView()
			} else {
				Label("Analysis", systemImage: "text.magnifyingglass")
			}
		}
		.accessibilityLabel("Analysis")
		.accessibilityValue(isAnalysing ? "Running" : "")
		.accessibilityIdentifier("board.analyse")
	}
}

private struct CanvasMenuContent: View {
	let board: Board
	let isReadOnly: Bool
	let isAnalysing: Bool
	let canUndo: Bool
	let canRedo: Bool
	let search: () -> Void
	let deepResearch: () -> Void
	let sendToChat: () -> Void
	let undo: () -> Void
	let redo: () -> Void
	let arrange: () -> Void

	var body: some View {
		Section {
			Button("Search", systemImage: "magnifyingglass", action: search)
				.accessibilityIdentifier("board.search")
		}

		// A person who can only view gets just what doesn't change the board
		if !isReadOnly {
			Section {
				Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
					.disabled(!canUndo)
				Button("Redo", systemImage: "arrow.uturn.forward", action: redo)
					.disabled(!canRedo)
			}

			Section {
				Button("Arrange", systemImage: "rectangle.3.group", action: arrange)
			}
		}

		Section {
			if !isReadOnly {
				Button("Deep Research", systemImage: "text.magnifyingglass", action: deepResearch)
					.disabled(isAnalysing)
					.accessibilityIdentifier("board.deepResearch")
			}
			Button("Send to Chat", systemImage: "bubble.left.and.text.bubble.right", action: sendToChat)
				.accessibilityIdentifier("board.sendToChat")
		}

		if !isReadOnly {
			Section {
				BoardPeopleButton(board: board)
			}
		}
	}
}
