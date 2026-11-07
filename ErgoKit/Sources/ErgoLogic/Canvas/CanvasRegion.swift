//
//  CanvasRegion.swift
//  ErgoKit
//
//  Created by Adon Omeri on 7/11/2026.
//

import Foundation

/// The shape around a source and the cards made from it. It's worked out from where they are and never stored, so it
/// follows them as they move.
///
/// The shape hugs what's there: a band around each card and along each arrow, melted together where they come close, so
/// it goes in wherever the arrangement leaves a gap. It's found by measuring, at each point of a grid, how far the nearest
/// card or arrow is, and tracing where that distance reaches the band's edge. Only the lower half of the source counts,
/// so the source sits on the edge.
public enum CanvasRegion {
	/// An arrow between two cards of a region
	public struct Arrow: Hashable, Sendable {
		public var from: CanvasPoint
		public var to: CanvasPoint

		public init(from: CanvasPoint, to: CanvasPoint) {
			self.from = from
			self.to = to
		}
	}

	/// Room between a card and the edge
	public static let padding = 34.0

	/// Every outline has this many points, evenly spaced, so one shape can always slide into another
	public static let outlinePoints = 240

	/// A card dropped further than this from the rest of its region leaves it. Far enough that a card already at the far
	/// end doesn't leave, since the region's outline without it stops a whole row short.
	public static let leaveDistance = CanvasLayout.boxSize.height + CanvasLayout.rowGap + padding

	/// How far the band reaches either side of an arrow
	private static let arrowReach = 24.0

	/// A gap between two bands melts shut if it's under half of this, which closes the slit either side of an arrow between
	/// stacked cards (the row gap less a padding each side, 52). Rounds the inside corners where bands meet too.
	private static let melt = 110.0

	/// Canvas units between the points measured. The edge is placed between them, so it's finer than this.
	private static let gridStep = 12.0

	/// How many straight pieces an arrow's curve is measured as
	private static let arrowPieces = 6

	// MARK: - Outline

	/// The points round the edge, the same way round every time. A card with no arrow to the rest is joined on by the
	/// shortest way, so a region is always one piece.
	public static func outline(source: CanvasPoint, members: [CanvasPoint], arrows: [Arrow] = []) -> [CanvasPoint] {
		let size = CanvasLayout.boxSize
		let top = source.y + padding
		var shapes: [Shape] = [
			.box(
				minX: source.x - size.width / 2,
				maxX: source.x + size.width / 2,
				minY: min(top, source.y + size.height / 2),
				maxY: source.y + size.height / 2,
				reach: padding
			),
		]
		for member in members {
			let box = CanvasRect(center: member, size: size)
			shapes.append(.box(minX: box.minX, maxX: box.maxX, minY: box.minY, maxY: box.maxY, reach: padding))
		}
		for arrow in arrows {
			if let line = line(along: arrow) {
				shapes.append(.line(line, reach: arrowReach))
			}
		}
		for join in joins(source: source, members: members, arrows: arrows) {
			shapes.append(.line(join, reach: arrowReach))
		}

		let field = DistanceField(covering: shapes, step: gridStep, reachBeyond: melt)
		var measured = field
		for shape in shapes {
			measured.add(shape, melting: melt)
		}
		return resampled(measured.largestContour())
	}

	/// Where a source goes to sit on the top edge of `members`, centred over them
	public static func sourcePosition(above members: [CanvasPoint]) -> CanvasPoint? {
		guard let left = members.map(\.x).min(), let right = members.map(\.x).max(), let top = members.map(\.y).min() else { return nil }
		let height = CanvasLayout.boxSize.height
		return CanvasPoint(x: (left + right) / 2, y: top - height - padding)
	}

	// MARK: - Inside

	public static func contains(_ point: CanvasPoint, in outline: [CanvasPoint]) -> Bool {
		guard outline.count >= 3 else { return false }
		var isInside = false
		var previous = outline[outline.count - 1]
		for current in outline {
			if (current.y > point.y) != (previous.y > point.y) {
				let crossing = previous.x + (point.y - previous.y) / (current.y - previous.y) * (current.x - previous.x)
				if point.x < crossing {
					isInside.toggle()
				}
			}
			previous = current
		}
		return isInside
	}

	/// How far `point` is from the region. Zero inside it.
	public static func distance(from point: CanvasPoint, to outline: [CanvasPoint]) -> Double {
		if contains(point, in: outline) {
			return 0
		}
		var nearest = Double.infinity
		for (index, start) in outline.enumerated() {
			let segment = CanvasSegment(start: start, end: outline[(index + 1) % outline.count])
			nearest = min(nearest, CanvasGeometry.distance(from: point, to: segment))
		}
		return nearest
	}

	/// The region a card belongs to after being put down at `point`: one it's inside, its old one first, or else its old
	/// one while it's still close, or else none. `outlines` are worked out without the card, ids sorted so every device agrees.
	public static func home(of point: CanvasPoint, current: UUID?, outlines: [UUID: [CanvasPoint]]) -> UUID? {
		if let current, let outline = outlines[current], contains(point, in: outline) {
			return current
		}
		let inside = outlines.keys
			.sorted { $0.uuidString < $1.uuidString }
			.first { contains(point, in: outlines[$0] ?? []) }
		if let inside {
			return inside
		}
		if let current, let outline = outlines[current], distance(from: point, to: outline) <= leaveDistance {
			return current
		}
		return nil
	}

	// MARK: - What the band goes around

	/// The arrow's curve, the one that's drawn, as straight pieces
	private static func line(along arrow: Arrow) -> [CanvasPoint]? {
		let size = CanvasLayout.boxSize
		guard let segment = CanvasGeometry.arrow(from: CanvasRect(center: arrow.from, size: size), to: CanvasRect(center: arrow.to, size: size)) else { return nil }
		let control = CanvasGeometry.controlPoint(for: segment)
		return (0 ... arrowPieces).map { CanvasGeometry.point(on: segment, control: control, at: Double($0) / Double(arrowPieces)) }
	}

	/// Straight lines joining what arrows leave apart, nearest pairs first, so nothing floats off on its own. The first
	/// point stands for the source, at its bottom edge, since that's the half in the region.
	private static func joins(source: CanvasPoint, members: [CanvasPoint], arrows: [Arrow]) -> [[CanvasPoint]] {
		let points = [source + CanvasPoint(x: 0, y: CanvasLayout.boxSize.height / 2)] + members
		var group = Array(points.indices)

		func root(_ index: Int) -> Int {
			var index = index
			while group[index] != index {
				index = group[index]
			}
			return index
		}

		for arrow in arrows {
			guard let from = members.firstIndex(of: arrow.from), let to = members.firstIndex(of: arrow.to) else { continue }
			group[root(from + 1)] = root(to + 1)
		}

		var pairs: [(a: Int, b: Int, distance: Double)] = []
		for a in points.indices {
			for b in points.indices where b > a {
				pairs.append((a, b, points[a].distance(to: points[b])))
			}
		}
		pairs.sort { ($0.distance, $0.a, $0.b) < ($1.distance, $1.a, $1.b) }

		var lines: [[CanvasPoint]] = []
		for pair in pairs where root(pair.a) != root(pair.b) {
			group[root(pair.a)] = root(pair.b)
			lines.append([points[pair.a], points[pair.b]])
		}
		return lines
	}

	// MARK: - Spacing

	/// Evenly spaced along the edge, starting nearest the top left so one outline's points line up with the next one's
	private static func resampled(_ contour: [CanvasPoint]) -> [CanvasPoint] {
		guard contour.count >= 3 else { return contour }

		let lowest = contour.min { ($0.x + $0.y) < ($1.x + $1.y) } ?? contour[0]
		let start = contour.firstIndex(of: lowest) ?? 0
		let ring = Array(contour[start...] + contour[..<start]) + [lowest]

		var total = 0.0
		for index in 1 ..< ring.count {
			total += ring[index - 1].distance(to: ring[index])
		}
		guard total > 0 else { return contour }

		let spacing = total / Double(outlinePoints)
		var points: [CanvasPoint] = []
		var walked = 0.0
		var piece = 1
		for count in 0 ..< outlinePoints {
			let wanted = spacing * Double(count)
			while piece < ring.count - 1, walked + ring[piece - 1].distance(to: ring[piece]) < wanted {
				walked += ring[piece - 1].distance(to: ring[piece])
				piece += 1
			}
			let length = ring[piece - 1].distance(to: ring[piece])
			let fraction = length > 0 ? (wanted - walked) / length : 0
			points.append(ring[piece - 1] + (ring[piece] - ring[piece - 1]) * fraction)
		}
		return points
	}
}

// MARK: - Shapes

private enum Shape {
	case box(minX: Double, maxX: Double, minY: Double, maxY: Double, reach: Double)
	case line([CanvasPoint], reach: Double)

	/// Everything within `extra` of the band
	func bounds(extra: Double) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
		switch self {
			case let .box(minX, maxX, minY, maxY, reach):
				return (minX - reach - extra, maxX + reach + extra, minY - reach - extra, maxY + reach + extra)
			case let .line(points, reach):
				let xs = points.map(\.x)
				let ys = points.map(\.y)
				let around = reach + extra
				return ((xs.min() ?? 0) - around, (xs.max() ?? 0) + around, (ys.min() ?? 0) - around, (ys.max() ?? 0) + around)
		}
	}

	/// How far `point` is from the band's edge, negative inside it
	func distance(from point: CanvasPoint) -> Double {
		switch self {
			case let .box(minX, maxX, minY, maxY, reach):
				let dx = max(minX - point.x, point.x - maxX, 0)
				let dy = max(minY - point.y, point.y - maxY, 0)
				if dx > 0 || dy > 0 {
					return hypot(dx, dy) - reach
				}
				return -min(point.x - minX, maxX - point.x, point.y - minY, maxY - point.y) - reach

			case let .line(points, reach):
				var nearest = Double.infinity
				for index in 1 ..< points.count {
					let segment = CanvasSegment(start: points[index - 1], end: points[index])
					nearest = min(nearest, CanvasGeometry.distance(from: point, to: segment))
				}
				return nearest - reach
		}
	}
}

// MARK: - The grid

/// Distances on a grid, each new shape melted in where it's close to what's there. Each shape only touches the part of the
/// grid it can reach, so a big board costs what its cards do, and dragging one can do this every frame.
private struct DistanceField {
	private let step: Double
	private let originX: Double
	private let originY: Double
	private let columns: Int
	private let rows: Int
	private var values: [Double]

	init(covering shapes: [Shape], step: Double, reachBeyond: Double) {
		let bounds = shapes.map { $0.bounds(extra: reachBeyond) }
		let minX = bounds.map(\.minX).min() ?? 0
		let maxX = bounds.map(\.maxX).max() ?? 0
		let minY = bounds.map(\.minY).min() ?? 0
		let maxY = bounds.map(\.maxY).max() ?? 0

		self.step = step
		originX = minX - step
		originY = minY - step
		columns = Int(((maxX - minX) / step).rounded(.up)) + 3
		rows = Int(((maxY - minY) / step).rounded(.up)) + 3
		values = Array(repeating: .greatestFiniteMagnitude, count: columns * rows)
	}

	/// A smooth minimum: the nearer of the two, and lower still where they're about equal, which is what closes gaps
	mutating func add(_ shape: Shape, melting melt: Double) {
		let bounds = shape.bounds(extra: melt)
		let firstColumn = max(Int(((bounds.minX - originX) / step).rounded(.down)), 0)
		let lastColumn = min(Int(((bounds.maxX - originX) / step).rounded(.up)), columns - 1)
		let firstRow = max(Int(((bounds.minY - originY) / step).rounded(.down)), 0)
		let lastRow = min(Int(((bounds.maxY - originY) / step).rounded(.up)), rows - 1)
		guard firstColumn <= lastColumn, firstRow <= lastRow else { return }

		for row in firstRow ... lastRow {
			let y = originY + Double(row) * step
			for column in firstColumn ... lastColumn {
				let new = shape.distance(from: CanvasPoint(x: originX + Double(column) * step, y: y))
				let index = row * columns + column
				let old = values[index]
				let closeness = max(melt - abs(old - new), 0) / melt
				values[index] = min(old, new) - closeness * closeness * melt / 4
			}
		}
	}

	/// The longest-reaching loop where the distance crosses zero. Anything inside it, like the pocket between two arrows,
	/// is another loop and isn't kept, so the region fills it.
	func largestContour() -> [CanvasPoint] {
		var neighbours: [Int: [Int]] = [:]
		neighbours.reserveCapacity(512)

		func connect(_ a: Int, _ b: Int) {
			neighbours[a, default: []].append(b)
			neighbours[b, default: []].append(a)
		}

		for row in 0 ..< rows - 1 {
			for column in 0 ..< columns - 1 {
				let shape = (value(column, row) < 0 ? 1 : 0)
					| (value(column + 1, row) < 0 ? 2 : 0)
					| (value(column + 1, row + 1) < 0 ? 4 : 0)
					| (value(column, row + 1) < 0 ? 8 : 0)
				guard shape != 0, shape != 15 else { continue }

				let top = edge(column, row, isVertical: false)
				let right = edge(column + 1, row, isVertical: true)
				let bottom = edge(column, row + 1, isVertical: false)
				let left = edge(column, row, isVertical: true)

				switch shape {
					case 1, 14: connect(left, top)
					case 2, 13: connect(top, right)
					case 3, 12: connect(left, right)
					case 4, 11: connect(right, bottom)
					case 6, 9: connect(top, bottom)
					case 7, 8: connect(left, bottom)
					case 5:
						connect(left, top)
						connect(right, bottom)
					case 10:
						connect(top, right)
						connect(left, bottom)
					default:
						break
				}
			}
		}

		var largest: [CanvasPoint] = []
		var largestArea = 0.0
		var visited: Set<Int> = []
		for start in neighbours.keys where !visited.contains(start) {
			var loop: [CanvasPoint] = []
			var previous: Int?
			var current = start
			while !visited.contains(current) {
				visited.insert(current)
				loop.append(crossing(on: current))
				let next = neighbours[current]?.first { $0 != previous && !visited.contains($0) }
				guard let next else { break }
				previous = current
				current = next
			}

			let area = Self.signedArea(of: loop)
			if abs(area) > largestArea {
				largestArea = abs(area)
				largest = area < 0 ? loop.reversed() : loop
			}
		}
		return largest
	}

	private func value(_ column: Int, _ row: Int) -> Double {
		values[row * columns + column]
	}

	/// A grid edge's id: the corner it starts at, and which way it goes
	private func edge(_ column: Int, _ row: Int, isVertical: Bool) -> Int {
		(row * columns + column) * 2 + (isVertical ? 1 : 0)
	}

	/// Where the distance reaches zero along a grid edge
	private func crossing(on edge: Int) -> CanvasPoint {
		let isVertical = edge % 2 == 1
		let corner = edge / 2
		let row = corner / columns
		let column = corner % columns
		let start = value(column, row)
		let end = isVertical ? value(column, row + 1) : value(column + 1, row)
		let fraction = start == end ? 0.5 : start / (start - end)

		let x = originX + Double(column) * step
		let y = originY + Double(row) * step
		return isVertical
			? CanvasPoint(x: x, y: y + fraction * step)
			: CanvasPoint(x: x + fraction * step, y: y)
	}

	private static func signedArea(of loop: [CanvasPoint]) -> Double {
		var area = 0.0
		for (index, point) in loop.enumerated() {
			let next = loop[(index + 1) % loop.count]
			area += point.x * next.y - next.x * point.y
		}
		return area / 2
	}
}
