//
//  CanvasView+Outline.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import SwiftUI

extension CanvasView {
	/// The board as a list in the canvas's place. The canvas isn't there underneath, so nothing reaches it by keyboard
	/// or VoiceOver. A row opens the same editor a box does, and deletes the same way, so the bar, undo and view-only
	/// boards all work as on the canvas.
	var outline: some View {
		BoardOutlineView(
			board: board,
			isReadOnly: isReadOnly,
			counts: shownAnalysis.counts,
			findHighlight: find?.query,
			open: { id in
				// The bar's "pick the other end" still works by tapping a row
				if activePick != nil {
					select(id)
				} else {
					edit(id)
				}
			},
			openSource: { id in open(id) },
			delete: { id in delete(id) },
			deleteSource: { id in deleteSource(id) }
		)
		// The canvas comes back as a new view, at no particular pan or zoom
		.onDisappear {
			Task {
				fit(animated: false)
			}
		}
	}

	/// Where the editor looks for the box to open out of. In the outline there's no box on screen, and the controller
	/// still holds the canvas that was taken away, so it gets an empty one and the editor fades in instead.
	var editorBoxes: CanvasBoardController {
		boardLayout == .outline ? CanvasBoardController() : canvasBoard
	}
}
