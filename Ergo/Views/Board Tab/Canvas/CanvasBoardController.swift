//
//  CanvasBoardController.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// How SwiftUI reaches the pan and zoom, which live in `CanvasBoardView` so they never have to go through a SwiftUI update
@MainActor
final class CanvasBoardController {
	var view: CanvasBoardView? {
		didSet {
			if let pending, let view {
				view.move(to: pending, animation: nil)
				self.pending = nil
			}
		}
	}

	/// A fit asked for before the view exists
	private var pending: CanvasTransform?

	var transform: CanvasTransform {
		view?.canvasTransform ?? pending ?? CanvasTransform()
	}

	/// Whether the person has panned or zoomed yet
	var hasBeenMoved: Bool {
		view?.hasBeenMoved ?? false
	}

	/// The view of a box on the canvas, for the editor to zoom out of
	func box(_ id: Statement.ID) -> UIView? {
		view?.box(id)
	}

	func move(to transform: CanvasTransform, animation: Animation?) {
		if let view {
			view.move(to: transform, animation: animation)
		} else {
			pending = transform
		}
	}
}
