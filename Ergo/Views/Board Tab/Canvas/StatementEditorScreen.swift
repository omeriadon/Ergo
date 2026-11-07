//
//  StatementEditorScreen.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// The statement editor as the canvas shows it: a sheet the box zooms into, and back into when it closes.
struct StatementEditorScreen: View {
	let statementID: Statement.ID
	let zoomNamespace: Namespace.ID

	@Environment(\.dismiss)
	private var dismiss

	@Environment(BoardStore.self)
	private var boardStore

	/// False once the statement is gone (deleted on another device), and there's nothing left to edit
	private var exists: Bool {
		boardStore.statement(statementID) != nil
	}

	var body: some View {
		NavigationStack {
			StatementEditorView(statementID: statementID)
		}
		.presentationDetents([.fraction(0.8)])
		.presentationDragIndicator(.visible)
		.navigationTransition(.zoom(sourceID: statementID, in: zoomNamespace))
		.onChange(of: exists) { _, exists in
			if !exists {
				dismiss()
			}
		}
	}
}
