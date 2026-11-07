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

	/// Undo steps belong to the board they were made on, so they live here and are dropped when the board changes
	@State private var history = CanvasHistory()

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
		.onChange(of: boardStore.current.id) {
			history.clear()
		}
	}
}
