//
//  CheckTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

/// The Check tab: the current page as a canvas of statements, and the editor a statement zooms into.
struct CheckTabView: View {
	@Environment(PageStore.self)
	private var pageStore

	/// The box the editor zooms out of, and back into
	@Namespace private var zoom

	/// The statement whose editor is open
	@State private var editing: Statement.ID?

	/// Undo steps belong to the page they were made on, so they live here and are dropped when the page changes
	@State private var history = CanvasHistory()

	var body: some View {
		ZStack {
			// A different page starts with its own pan, zoom and selection
			CanvasView(zoomNamespace: zoom, history: history, isCovered: editing != nil) { editing = $0 }
				.id(pageStore.current.id)
		}
		.containerBackground(for: .navigation) { CanvasBackdrop() }
		.navigationDestination(item: $editing) { id in
			StatementEditorScreen(statementID: id, zoomNamespace: zoom)
		}
		.onChange(of: pageStore.current.id) {
			editing = nil
			history.clear()
		}
	}
}
