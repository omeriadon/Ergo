//
//  CanvasToolbar.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoSync
import SwiftUI

/// Fit, Analyse and Boards, and the menu for everything that changes the board
struct CanvasToolbar: ToolbarContent {
	let board: Board
	let isReadOnly: Bool
	let isAnalysing: Bool
	let canUndo: Bool
	let canRedo: Bool
	let fit: () -> Void
	let showBoards: () -> Void
	let analyse: () -> Void
	let undo: () -> Void
	let redo: () -> Void
	let arrange: () -> Void

	var body: some ToolbarContent {
		ToolbarItemGroup(placement: .topBarTrailing) {
			Button("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass", action: fit)
				.accessibilityIdentifier("board.fitButton")

			// Not on a board this person can only view. They still see the annotations.
			if !isReadOnly {
				AnalyseButton(isAnalysing: isAnalysing, analyse: analyse)
			}

			Button("Boards", systemImage: "text.page.and.line.vertical.and.text.page", action: showBoards)
				.accessibilityIdentifier("board.boardsButton")
		}

		// Everything in it changes the board
		if !isReadOnly {
			ToolbarOverflowMenu {
				CanvasMenuContent(
					board: board,
					canUndo: canUndo,
					canRedo: canRedo,
					undo: undo,
					redo: redo,
					arrange: arrange
				)
			}
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
				Label("Analyse", systemImage: "text.magnifyingglass")
			}
		}
		.accessibilityLabel("Analyse")
		.accessibilityValue(isAnalysing ? "Running" : "")
		.accessibilityIdentifier("board.analyse")
	}
}

private struct CanvasMenuContent: View {
	let board: Board
	let canUndo: Bool
	let canRedo: Bool
	let undo: () -> Void
	let redo: () -> Void
	let arrange: () -> Void

	var body: some View {
		Section {
			Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
				.disabled(!canUndo)
			Button("Redo", systemImage: "arrow.uturn.forward", action: redo)
				.disabled(!canRedo)
		}

		Section {
			Button("Arrange", systemImage: "rectangle.3.group", action: arrange)
		}

		Section {
			BoardPeopleButton(board: board)
		}
	}
}
