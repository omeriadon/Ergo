//
//  CheckTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

/// The Check tab: the current board as a canvas of statements, and the editor a statement zooms into.
struct CheckTabView: View {
	@Environment(BoardStore.self)
	private var boardStore

	/// The box the editor zooms out of, and back into
	@Namespace private var zoom

	/// The statement whose editor is open
	@State private var editing: Statement.ID?

	/// Undo steps belong to the board they were made on, so they live here and are dropped when the board changes
	@State private var history = CanvasHistory()

	@State private var topInset: CGFloat = 70

	var body: some View {
		ZStack {
			// A different board starts with its own pan, zoom and selection
			CanvasView(zoomNamespace: zoom, history: history, isCovered: editing != nil) { editing = $0 }
				.overlay(alignment: .top) {
					BackdropBlur(radius: 3, fade: .bottom)
						.frame(height: topInset)
						.ignoresSafeArea()
				}
				.background(
					GeometryReader { geometry in
						Color.clear
							.onAppear {
								topInset = geometry.safeAreaInsets.top
							}
							.onChange(of: geometry.safeAreaInsets.top) { _, newValue in
								topInset = newValue
							}
					}
				)
				.id(boardStore.current.id)
		}
		.containerBackground(for: .navigation) { CanvasBackdrop() }
		.navigationDestination(item: $editing) { id in
			StatementEditorScreen(statementID: id, zoomNamespace: zoom)
		}
		.onChange(of: boardStore.current.id) {
			editing = nil
			history.clear()
		}
	}
}
