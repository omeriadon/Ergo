//
//  StatementEditorCard.swift
//  Ergo
//

import SwiftUI

/// The statement editor in a wide window: the box grows into a bigger card over the dimmed canvas, and shrinks back
/// into it when it's done. A window this size has room to keep the board in view, so the editor doesn't cover it the way
/// the narrow layout's zoom does.
///
/// It's inside `CanvasView`, so unlike the narrow layout's hosted editor it gets the app's environment.
struct StatementEditorCard: View {
	let statementID: Statement.ID
	let close: () -> Void

	@Environment(BoardStore.self)
	private var boardStore

	/// False once the statement is gone (deleted on another device), and there's nothing left to edit
	private var exists: Bool {
		boardStore.statement(statementID) != nil
	}

	var body: some View {
		VStack(spacing: 0) {
			header

			StatementEditorView(statementID: statementID, close: close, isInCard: true)
				.padding(.bottom, 12)
		}
		.frame(maxWidth: 560, maxHeight: 360)
		.glassEffect(.regular, in: .rect(cornerRadius: 26))
		.shadow(color: .black.opacity(0.18), radius: 30, y: 12)
		.padding(32)
		.onChange(of: exists) { _, exists in
			if !exists {
				close()
			}
		}
	}

	private var header: some View {
		HStack {
			Text("Card")
				.font(.headline)

			Spacer(minLength: 0)

			Button(role: .confirm) {
				boardStore.save()
				close()
			} label: {
				Label("Done", systemImage: "checkmark")
			}
			.buttonStyle(.glassProminent)
			// Escape, as it would close a sheet
			.keyboardShortcut(.cancelAction)
			.accessibilityIdentifier("board.doneButton")
		}
		.padding(.horizontal, 20)
		.padding(.top, 16)
		.padding(.bottom, 8)
	}
}

/// The card, over a backdrop that closes it when it's clicked
struct StatementEditorCardLayer: View {
	let statementID: Statement.ID?

	/// Where the box is, as a fraction of the canvas, for the card to grow out of and shrink back into
	let anchor: (Statement.ID) -> UnitPoint
	let close: () -> Void

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	private func transition(_ id: Statement.ID) -> AnyTransition {
		reduceMotion ? .opacity : .scale(scale: 0.25, anchor: anchor(id)).combined(with: .opacity)
	}

	var body: some View {
		ZStack {
			if let statementID {
				Color.black.opacity(0.18)
					.contentShape(.rect)
					.onTapGesture(perform: close)
					.accessibilityHidden(true)
					.transition(.opacity)

				StatementEditorCard(statementID: statementID, close: close)
					.id(statementID)
					.transition(transition(statementID))
			}
		}
		.animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.34), value: statementID)
	}
}
