//
//  BoardTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

/// The Board tab: the current board as a canvas of statements.
struct BoardTabView: View {
	@Environment(BoardStore.self)
	private var boardStore

	/// Undo steps belong to the board they were made on, so they live here and are dropped when the board changes. The
	/// wide layout hands down one that outlives this view, since it removes the board when another section is chosen.
	@State private var ownHistory = CanvasHistory()

	@Environment(\.canvasHistory)
	private var sharedHistory

	private var history: CanvasHistory {
		sharedHistory ?? ownHistory
	}

	@State private var topInset: CGFloat = 70

	var body: some View {
		ZStack {
			// A different board starts with its own pan, zoom and selection
			CanvasView(history: history)
				.overlay(alignment: .top) {
					BackdropBlur(radius: 3, fade: .bottom)
						.frame(height: topInset)
						.ignoresSafeArea()
				}
				.background(
					GeometryReader { geometry in
						Color.clear
							.onChange(of: geometry.safeAreaInsets.top, initial: true) { _, newValue in
								topInset = newValue
							}
					}
				)
				.id(boardStore.current.id)
		}
		#if os(macOS)
		// A Mac's navigation container is the whole window, sidebar included, so the backdrop stays behind the board
		.background { CanvasBackdrop().ignoresSafeArea() }
		#else
		.containerBackground(for: .navigation) { CanvasBackdrop() }
		#endif
		.onChange(of: boardStore.current.id) {
			history.clear()
		}
	}
}
