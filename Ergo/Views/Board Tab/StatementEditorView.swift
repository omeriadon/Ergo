//
//  StatementEditorView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

/// The English of one statement of the current board, in a plain editor. It reads and writes through `BoardStore`,
/// so it follows what other devices change.
struct StatementEditorView: View {
	@Environment(\.dismiss)
	private var dismiss

	@Environment(BoardStore.self)
	private var boardStore

	/// A statement of `boardStore.current`
	let statementID: Statement.ID

	@State private var englishSelection: TextSelection?
	@FocusState private var englishFocused: Bool

	/// Empty once the statement is gone (deleted on another device), until the screen moves on
	private var statement: Statement {
		boardStore.statement(statementID) ?? Statement(id: statementID)
	}

	/// Writes are dropped once the statement is gone
	private var statementBinding: Binding<Statement> {
		boardStore.binding(for: statementID) ?? .constant(statement)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			TextEditor(text: statementBinding.english, selection: $englishSelection)
				.textEditorStyle(.plain)
				.focused($englishFocused)
				.accessibilityLabel("English editor")
				.accessibilityIdentifier("board.englishEditor")
		}
		.padding(15)
		.glassEffect(
			.regular.interactive(),
			in: RoundedRectangle(cornerRadius: 20)
		)
		.padding(15)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.onChange(of: statementID) {
			englishSelection = nil
		}
		.onChange(of: boardStore.remoteEdits) {
			// Another device changed this board, and the selection was into the old English
			englishSelection = nil
		}
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				// With the keyboard up the button puts it away, and then it closes the editor
				Button(role: .confirm) {
					if englishFocused {
						englishFocused = false
					} else {
						dismiss()
					}
				} label: {
					// Toolbar items don't pick up the animation on the body, so it has to be here
					ZStack {
						let symbol = englishFocused ? "checkmark" : "app.badge.checkmark"
						Image(systemName: symbol)
							.id(symbol)
							.transition(.blurReplace)
					}
					.animation(.smooth, value: englishFocused)
				}
				.buttonStyle(.glassProminent)
				.accessibilityLabel("Done")
				.accessibilityIdentifier("board.doneButton")
			}
		}
		.animation(.easeInOut, value: englishFocused)
	}
}
