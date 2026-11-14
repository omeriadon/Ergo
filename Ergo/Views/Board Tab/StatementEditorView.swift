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
	@Environment(BoardStore.self)
	private var boardStore

	/// A statement of `boardStore.current`
	let statementID: Statement.ID
	let close: () -> Void

	@State private var englishSelection: TextSelection?
	@FocusState private var englishFocused: Bool

	/// Empty once the statement is gone (deleted on another device), until the editor closes
	private var statement: Statement {
		boardStore.statement(statementID) ?? Statement(id: statementID)
	}

	/// Writes are dropped once the statement is gone
	private var statementBinding: Binding<Statement> {
		boardStore.binding(for: statementID) ?? .constant(statement)
	}

	/// Comes from the store, so a role changing while this is open applies straight away
	private var canEdit: Bool {
		boardStore.canEdit(boardStore.current.id)
	}

	@ViewBuilder
	private var content: some View {
		if canEdit {
			TextEditor(text: statementBinding.english, selection: $englishSelection)
				.textEditorStyle(.plain)
				.focused($englishFocused)
				.padding(.horizontal, 15)
				.accessibilityLabel("English editor")
				.accessibilityIdentifier("board.englishEditor")
				.overlay(alignment: .topLeading) { placeholder }
		} else {
			ScrollView {
				Text(statement.english.isEmpty ? statement.placeholderText : statement.english)
					.foregroundStyle(statement.english.isEmpty ? .secondary : .primary)
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.horizontal, 20)
					.accessibilityIdentifier("board.englishReader")
			}
		}
	}

	/// `TextEditor` has no prompt of its own, so a template's placeholder sits over it until something's written
	@ViewBuilder
	private var placeholder: some View {
		if statement.english.isEmpty, let placeholder = statement.placeholder {
			Text(placeholder)
				.foregroundStyle(.tertiary)
				.padding(.horizontal, 20)
				.padding(.top, 8)
				.allowsHitTesting(false)
				.accessibilityHidden(true)
		}
	}

	var body: some View {
		content
			.toolbarTitleDisplayMode(.inline)
			.navigationTitle("Card")
			.onAppear {
				// Nothing to read yet, so it's ready to write in
				if statement.english.isEmpty {
					englishFocused = true
				}
			}
			.onChange(of: statementID) {
				englishSelection = nil
			}
			.onChange(of: boardStore.remoteEdits) {
				// Another device changed this board, and the selection was into the old English
				englishSelection = nil
			}
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .confirm) {
						boardStore.save()
						close()
					} label: {
						Label("Done", systemImage: "checkmark")
					}
					.buttonStyle(.glassProminent)
					.accessibilityIdentifier("board.doneButton")
				}
			}
	}
}
