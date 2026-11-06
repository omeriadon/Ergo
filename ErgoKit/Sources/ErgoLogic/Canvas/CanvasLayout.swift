//
//  CanvasLayout.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

/// Where boxes go. Layers run left to right: premises sit left of their conclusion, and a statement's layer is the
/// longest chain of premises behind it. Nothing here looks at current positions, so the same map always gives the same layout.
public enum CanvasLayout {
	/// The box the layout assumes. The app draws boxes this size so nothing overlaps.
	public static let boxSize = CanvasSize(width: 220, height: 96)

	public static let columnGap = 96.0
	public static let rowGap = 40.0

	/// Boxes dropped by `place` keep at least this much clear space from their neighbours
	public static let minimumGap = 24.0

	public static var columnPitch: Double {
		boxSize.width + columnGap
	}

	public static var rowPitch: Double {
		boxSize.height + rowGap
	}

	// MARK: - Auto layout

	/// New centres for every statement, with the top left box edge at (0, 0)
	public static func positions(for map: ArgumentMap<some Any, some Any>) -> [UUID: CanvasPoint] {
		let order = map.topologicalOrder(tieBreak: .listing)
		let known = Set(order)

		var premises: [UUID: [UUID]] = [:]
		for link in map.links where link.premise != link.conclusion && known.contains(link.premise) && known.contains(link.conclusion) {
			premises[link.conclusion, default: []].append(link.premise)
		}

		// Longest path from a root. Back edges of a cycle point at statements with no layer yet, so they're skipped.
		var layerOf: [UUID: Int] = [:]
		var layers: [[UUID]] = []
		for id in order {
			let layer = (premises[id] ?? []).compactMap { layerOf[$0] }.max().map { $0 + 1 } ?? 0
			layerOf[id] = layer
			if layer == layers.count {
				layers.append([])
			}
			layers[layer].append(id)
		}

		var listing: [UUID: Int] = [:]
		for (index, statement) in map.statements.enumerated() where listing[statement.id] == nil {
			listing[statement.id] = index
		}

		// Each layer aims for the average height of its premises, then packs downwards so rows never overlap
		var y: [UUID: Double] = [:]
		for (index, layer) in layers.enumerated() {
			let wanted = Dictionary(uniqueKeysWithValues: layer.map { id -> (UUID, Double) in
				let heights = (premises[id] ?? []).compactMap { y[$0] }
				return (id, heights.isEmpty ? 0 : heights.reduce(0, +) / Double(heights.count))
			})
			let sorted = index == 0 ? layer : layer.sorted { (wanted[$0] ?? 0, listing[$0] ?? 0) < (wanted[$1] ?? 0, listing[$1] ?? 0) }

			var placed: [Double] = []
			for (row, id) in sorted.enumerated() {
				let target = index == 0 ? Double(row) * rowPitch : wanted[id] ?? 0
				placed.append(max(target, (placed.last ?? -.infinity) + rowPitch))
			}

			if index > 0 {
				// Packing only ever pushes down, so shift the whole layer back to centre on where it wanted to be
				let shift = (sorted.map { wanted[$0] ?? 0 }.reduce(0, +) - placed.reduce(0, +)) / Double(sorted.count)
				placed = placed.map { $0 + shift }
			}

			for (id, height) in zip(sorted, placed) {
				y[id] = height
			}
		}

		let top = y.values.min() ?? 0
		var result: [UUID: CanvasPoint] = [:]
		for (id, layer) in layerOf {
			result[id] = CanvasPoint(
				x: Double(layer) * columnPitch + boxSize.width / 2,
				y: (y[id] ?? 0) - top + boxSize.height / 2
			)
		}
		return result
	}

	/// The map with every statement moved to its laid out position
	public static func arranged<Node, Link>(_ map: ArgumentMap<Node, Link>) -> ArgumentMap<Node, Link> {
		let positions = positions(for: map)
		var map = map
		for index in map.statements.indices {
			if let position = positions[map.statements[index].id] {
				map.statements[index].position = position
			}
		}
		return map
	}

	// MARK: - Placing one box

	public enum Side: Sendable {
		/// Where a premise goes
		case left
		/// Where a conclusion goes
		case right
		/// Where a sibling goes
		case below
	}

	/// A free spot beside the statement `id`, nearest first. Falls back to beside the origin when `id` isn't in the map.
	public static func place(newNodeNear id: UUID, in map: ArgumentMap<some Any, some Any>, side: Side = .left) -> CanvasPoint {
		place(near: map.statement(id)?.position ?? .zero, side: side, occupied: map.statements.map(\.position))
	}

	/// Tries the column (or row, for `.below`) next to `anchor` at the anchor's height, then alternately further down and up,
	/// then moves a column further out. There are only so many boxes, so a free spot turns up eventually.
	public static func place(near anchor: CanvasPoint, side: Side, occupied: [CanvasPoint]) -> CanvasPoint {
		let steps: (primary: CanvasPoint, secondary: CanvasPoint) = switch side {
			case .left: (CanvasPoint(x: -columnPitch, y: 0), CanvasPoint(x: 0, y: rowPitch))
			case .right: (CanvasPoint(x: columnPitch, y: 0), CanvasPoint(x: 0, y: rowPitch))
			case .below: (CanvasPoint(x: 0, y: rowPitch), CanvasPoint(x: columnPitch, y: 0))
		}

		func isFree(_ candidate: CanvasPoint) -> Bool {
			let box = CanvasRect(center: candidate, size: boxSize)
			return !occupied.contains { box.intersects(CanvasRect(center: $0, size: boxSize), margin: minimumGap) }
		}

		let limit = occupied.count + 1
		for distance in 1 ... 2 * limit {
			let base = anchor + steps.primary * Double(distance)
			for offset in 0 ... limit {
				for direction in offset == 0 ? [1.0] : [1.0, -1.0] {
					let candidate = base + steps.secondary * (Double(offset) * direction)
					if isFree(candidate) {
						return candidate
					}
				}
			}
		}

		return anchor + steps.primary * Double(2 * limit + 1)
	}
}
