//
//  CanvasBoardView+Regions.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI
import UIKit

extension CanvasBoardView {
	// MARK: - Regions

	func updateRegions(animation: TimeInterval?) {
		let wanted = Set(regions.map(\.source))
		for (id, layer) in regionLayers where !wanted.contains(id) {
			regionLayers[id] = nil
			layer.removeFromSuperlayer()
		}
		for region in regions {
			update(region, animation: animation)
		}
		styleRegions()
	}

	/// While a box moves, only the region it's in changes
	func updateRegion(holding id: Statement.ID, animation: TimeInterval?) {
		for region in regions where region.members.contains(id) {
			update(region, animation: animation)
		}
	}

	func updateRegion(of id: BoardSource.ID, animation: TimeInterval?) {
		for region in regions where region.source == id {
			update(region, animation: animation)
		}
	}

	func update(_ region: CanvasRegionModel, animation: TimeInterval?) {
		guard let source = sourceCells[region.source]?.center else { return }

		let layer: CanvasRegionLayer
		if let existing = regionLayers[region.source] {
			layer = existing
		} else {
			layer = CanvasRegionLayer(in: regionLayer)
			regionLayers[region.source] = layer
		}

		let members = region.members.compactMap { cells[$0].map { CanvasPoint($0.center) } }
		let arrows = links.compactMap { link -> CanvasRegion.Arrow? in
			guard region.members.contains(link.premise), region.members.contains(link.conclusion),
			      let from = cells[link.premise]?.center, let to = cells[link.conclusion]?.center
			else { return nil }
			return CanvasRegion.Arrow(from: CanvasPoint(from), to: CanvasPoint(to))
		}
		layer.setOutline(CanvasRegion.outline(source: CanvasPoint(source), members: members, arrows: arrows), animation: animation)
	}

	func styleRegions() {
		let accent = UIColor(Color.accent).resolvedColor(with: traitCollection)
		for layer in regionLayers.values {
			layer.style(accent: accent)
		}
	}

	/// A tap each time what's being dragged reaches the next grid point, which is where it would settle if let go
	func feelGrid(at point: CGPoint) {
		let nearest = CanvasGrid.snapped(CanvasPoint(point))
		if let gridPoint, gridPoint != nearest {
			haptics.crossedGridLine()
		}
		gridPoint = nearest
	}
}
