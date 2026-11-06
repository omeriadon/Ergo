//
//  CanvasGrid.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic

/// The invisible grid boxes snap their centres to while they are dragged
enum CanvasGrid {
	/// Canvas units between grid points
	static let step = 24.0

	/// The grid point nearest to `point`
	static func snapped(_ point: CanvasPoint) -> CanvasPoint {
		CanvasPoint(x: (point.x / step).rounded() * step, y: (point.y / step).rounded() * step)
	}
}
