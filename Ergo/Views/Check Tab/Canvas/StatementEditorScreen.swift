//
//  StatementEditorScreen.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// The statement editor as the canvas shows it: the box zooms into it, and a pinch out (or the back button, or
/// the edge swipe) zooms back out to the canvas. The pinch is a shortcut only, nothing needs it.
struct StatementEditorScreen: View {
	/// Fingers coming together past this means "back out"
	private static let dismissScale: CGFloat = 0.7

	let statementID: Statement.ID
	let zoomNamespace: Namespace.ID

	@Environment(\.dismiss)
	private var dismiss

	@Environment(PageStore.self)
	private var pageStore

	/// The pinch keeps reporting after it has gone far enough, and backing out once is all it means
	@State private var hasPinchedOut = false

	/// Nil once the statement is gone (deleted on another device), and there's nothing left to edit
	private var exists: Bool {
		pageStore.statement(statementID) != nil
	}

	var body: some View {
		StatementEditorView(statementID: statementID)
			.containerBackground(for: .navigation) { CanvasBackdrop() }
			.navigationTransition(.zoom(sourceID: statementID, in: zoomNamespace))
			.simultaneousGesture(
				MagnifyGesture()
					.onChanged { value in
						if !hasPinchedOut, value.magnification < Self.dismissScale {
							hasPinchedOut = true
							dismiss()
						}
					}
					.onEnded { _ in
						hasPinchedOut = false
					}
			)
			.onChange(of: exists) { _, exists in
				if !exists {
					dismiss()
				}
			}
	}
}
