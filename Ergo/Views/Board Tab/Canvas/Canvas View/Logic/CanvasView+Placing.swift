//
//  CanvasView+Placing.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoSync
import SwiftUI

extension CanvasView {
	// MARK: - Placing

	/// The middle of the part of the canvas the bars leave free
	var viewCentre: CanvasPoint {
		canvasBoard.transform.canvas(CGPoint(x: room.free.midX, y: room.free.midY))
	}

	/// The grid point nearest `point` where a box fits, else the nearest gap on that `side` of it
	func freeSpot(near point: CanvasPoint, side: CanvasLayout.Side = .below) -> CanvasPoint {
		let target = CanvasGrid.snapped(point)
		let occupied = board.statements.map(\.position) + board.sources.map(\.position)
		let box = CanvasRect.box(at: target)
		if !occupied.contains(where: { box.intersects(.box(at: $0), margin: CanvasLayout.minimumGap) }) {
			return target
		}
		return CanvasLayout.place(near: target, side: side, occupied: occupied)
	}

	var fitted: CanvasTransform {
		CanvasTransform.fitting(board.occupiedRects, in: room.viewport, insets: room.insets)
	}

	func fit(animated: Bool) {
		canvasBoard.move(to: fitted, animation: animated ? motion : nil)
	}

	// MARK: - Background

	func backgroundTapped(at point: CanvasPoint) {
		guard activePick == nil else {
			pick = nil
			return
		}

		let link = LinkHitTest.link(
			near: point,
			tolerance: 24 / canvasBoard.transform.scale,
			in: board.links,
			positions: Dictionary(board.statements.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })
		)
		selection = link.map { .link($0) }
	}

	var selectedStatement: Statement.ID? {
		if case let .statement(id)? = activeSelection {
			id
		} else {
			nil
		}
	}

	var selectedSource: BoardSource.ID? {
		if case let .source(id)? = activeSelection {
			id
		} else {
			nil
		}
	}

	var selectedLink: Link.ID? {
		if case let .link(id)? = activeSelection {
			id
		} else {
			nil
		}
	}
}
