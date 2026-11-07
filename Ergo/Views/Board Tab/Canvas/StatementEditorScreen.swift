//
//  StatementEditorScreen.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// The statement editor as the canvas shows it: the box zooms into it, and a pinch out (or the done button) zooms back out to the canvas. The pinch is a shortcut only, nothing needs it.
struct StatementEditorScreen: View {
	/// Fingers coming together past this means "back out"
	private static let dismissScale: CGFloat = 0.7

	let statementID: Statement.ID
	let close: () -> Void

	@Environment(BoardStore.self)
	private var boardStore

	/// The pinch keeps reporting after it has gone far enough, and backing out once is all it means
	@State private var hasPinchedOut = false

	/// False once the statement is gone (deleted on another device), and there's nothing left to edit
	private var exists: Bool {
		boardStore.statement(statementID) != nil
	}

	var body: some View {
		NavigationStack {
			StatementEditorView(statementID: statementID, close: close)
				.simultaneousGesture(
					MagnifyGesture()
						.onChanged { value in
							if !hasPinchedOut, value.magnification < Self.dismissScale {
								hasPinchedOut = true
								close()
							}
						}
						.onEnded { _ in
							hasPinchedOut = false
						}
				)
		}
		.onChange(of: exists) { _, exists in
			if !exists {
				close()
			}
		}
	}
}
