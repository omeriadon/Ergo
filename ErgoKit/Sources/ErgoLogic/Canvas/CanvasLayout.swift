//
//  CanvasLayout.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

/// Where boxes go. Layers run top to bottom: premises sit above their conclusion, and a statement's layer is the
/// longest chain of premises behind it. A layer too wide for a phone wraps onto more rows. Every row holds its boxes a
/// pitch apart and has a height of its own, and each box then sits a little off its spot so it doesn't look like a
/// spreadsheet. The gaps are wider than that `jiggle`, so no two boxes can overlap. Nothing here looks at current
/// positions, and each box's jiggle comes from its id, so the same map always gives the same layout on every device.
public enum CanvasLayout {
	/// The box the layout assumes. The app draws boxes this size so nothing overlaps.
	public static let boxSize = CanvasSize(width: 220, height: 96)

	public static let columnGap = 64.0

	/// Roomier than `columnGap`, since this is where the arrows between layers run
	public static let rowGap = 72.0

	/// Boxes dropped by `place` keep at least this much clear space from their neighbours
	public static let minimumGap = 24.0

	/// The furthest a laid out box sits from its spot, along each axis. Two neighbours leaning towards each other
	/// still keep `minimumGap` between them.
	public static let jiggle = 20.0

	/// The most boxes side by side in one row
	public static let maximumRowLength = 3

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

		// Each box aims for the average of its premises, then its row packs rightwards so boxes never overlap
		var x: [UUID: Double] = [:]
		var y: [UUID: Double] = [:]
		var rowTop = 0.0
		for layer in layers {
			let wanted = Dictionary(uniqueKeysWithValues: layer.map { id -> (UUID, Double) in
				let across = (premises[id] ?? []).compactMap { x[$0] }
				return (id, across.isEmpty ? 0 : across.reduce(0, +) / Double(across.count))
			})
			let sorted = layer.sorted { (wanted[$0] ?? 0, listing[$0] ?? 0) < (wanted[$1] ?? 0, listing[$1] ?? 0) }

			for start in stride(from: 0, to: sorted.count, by: maximumRowLength) {
				let row = sorted[start ..< min(start + maximumRowLength, sorted.count)]

				var placed: [Double] = []
				for id in row {
					placed.append(max(wanted[id] ?? 0, (placed.last ?? -.infinity) + columnPitch))
				}

				// Packing only ever pushes right, so shift the whole row back to centre on where it wanted to be
				let shift = (row.map { wanted[$0] ?? 0 }.reduce(0, +) - placed.reduce(0, +)) / Double(row.count)
				for (id, across) in zip(row, placed) {
					x[id] = across + shift
					y[id] = rowTop
				}
				rowTop += rowPitch
			}
		}

		var spots: [UUID: CanvasPoint] = [:]
		for id in order {
			spots[id] = CanvasPoint(x: x[id] ?? 0, y: y[id] ?? 0) + offset(of: id)
		}

		let left = spots.values.map(\.x).min() ?? 0
		let top = spots.values.map(\.y).min() ?? 0
		return spots.mapValues { CanvasPoint(x: $0.x - left + boxSize.width / 2, y: $0.y - top + boxSize.height / 2) }
	}

	/// How far off its spot this box sits. Hashed by hand, since `hashValue` changes every launch and this has to come out
	/// the same on every device.
	private static func offset(of id: UUID) -> CanvasPoint {
		var hash: UInt64 = 0xCBF2_9CE4_8422_2325
		withUnsafeBytes(of: id.uuid) { bytes in
			for byte in bytes {
				hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3
			}
		}
		hash = (hash ^ (hash >> 29)) &* 0xBF58_476D_1CE4_E5B9
		hash ^= hash >> 32

		func amount(_ bits: UInt64) -> Double {
			((Double(bits & 0xFFFF) / 0xFFFF * 2 - 1) * jiggle).rounded()
		}
		return CanvasPoint(x: amount(hash), y: amount(hash >> 16))
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
		case above
		/// Where a conclusion goes
		case below
		/// Where a sibling goes
		case beside
	}

	/// A free spot beside the statement `id`, nearest first. Falls back to beside the origin when `id` isn't in the map.
	public static func place(newNodeNear id: UUID, in map: ArgumentMap<some Any, some Any>, side: Side = .above) -> CanvasPoint {
		place(near: map.statement(id)?.position ?? .zero, side: side, occupied: map.statements.map(\.position))
	}

	/// Tries the row (or column, for `.beside`) next to `anchor` directly in line with it, then alternately further along either way,
	/// then moves a row further out. There are only so many boxes, so a free spot turns up eventually.
	public static func place(near anchor: CanvasPoint, side: Side, occupied: [CanvasPoint]) -> CanvasPoint {
		let steps: (primary: CanvasPoint, secondary: CanvasPoint) = switch side {
			case .above: (CanvasPoint(x: 0, y: -rowPitch), CanvasPoint(x: columnPitch, y: 0))
			case .below: (CanvasPoint(x: 0, y: rowPitch), CanvasPoint(x: columnPitch, y: 0))
			case .beside: (CanvasPoint(x: columnPitch, y: 0), CanvasPoint(x: 0, y: rowPitch))
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
