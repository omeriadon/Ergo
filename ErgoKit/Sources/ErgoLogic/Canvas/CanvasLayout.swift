//
//  CanvasLayout.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

/// Where boxes go. Layers run top to bottom, with premises above their conclusion, and each statement sits as close as
/// it can to what it's linked to, so arrows stay short. A layer too wide for a phone wraps onto more rows.
///
/// Rows are a fixed `rowPitch` apart and boxes sit on half-column steps, so every arrow between neighbouring rows is
/// straight down or at nearly one of a few angles. Arrows can't bend, so boxes keep out of the way of any arrow that skips
/// a row. Each box then sits a little off its spot so it doesn't look like a spreadsheet. The gaps are wider than that
/// `jiggle`, so it can't make boxes overlap or put one on an arrow.
///
/// Nothing here looks at current positions, and each box's jiggle comes from its id, so the same map always gives the
/// same layout on every device.
public enum CanvasLayout {
	/// The box the layout assumes. The app draws boxes this size so nothing overlaps.
	public static let boxSize = CanvasSize(width: 220, height: 96)

	public static let columnGap = 80.0

	/// Roomier than `columnGap`, since this is where the arrows between layers run
	public static let rowGap = 120.0

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

	/// New centres for every statement, with the top left box edge at (0, 0). Unlinked arguments sit side by side, tops
	/// level, and statements with no links at all go last as a plain grid.
	public static func positions(for map: ArgumentMap<some Any, some Any>) -> [UUID: CanvasPoint] {
		let order = map.topologicalOrder(tieBreak: .listing)
		let graph = LayeredGraph(order: order, links: map.links.map { ($0.premise, $0.conclusion) })

		var spots: [UUID: CanvasPoint] = [:]
		var groupLeft = 0.0
		for group in graph.groups {
			let rows = graph.rows(of: group)
			let across = graph.columns(for: rows)

			let xs = group.map { across[$0] }
			let left = xs.min() ?? 0
			for (index, row) in rows.enumerated() {
				for statement in row {
					let id = order[statement]
					spots[id] = CanvasPoint(x: across[statement] - left + groupLeft, y: Double(index) * rowPitch) + offset(of: id)
				}
			}

			// Half a column more than neighbours get, so separate arguments read as separate, and still on the grid
			groupLeft += (xs.max() ?? 0) - left + columnPitch * 1.5
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

/// The working behind `CanvasLayout.positions`. Statements are their place in the topological order, so every arrow
/// here points from a lower number to a higher one. Links caught in a cycle point backwards and are left out.
private struct LayeredGraph {
	typealias Arrow = (premise: Int, conclusion: Int)

	private static let half = CanvasLayout.columnPitch / 2

	/// How many half-column steps a row searches either way for its best spot
	private static let searchReach = 12

	/// Enough for the sweeps to settle. The best one is kept, so more only costs time.
	private static let sweeps = 12

	private static let repairPasses = 3
	private static let repairReach = 4

	/// What a layout pays, in columns squared of arrow slant, for an arrow through a box and for two arrows crossing
	private static let hitCost = 1000.0
	private static let crossingCost = 20.0

	private let count: Int
	private var arrows: [Arrow] = []
	private var premises: [[Int]]
	private var conclusions: [[Int]]

	init(order: [UUID], links: [(UUID, UUID)]) {
		count = order.count
		premises = Array(repeating: [], count: order.count)
		conclusions = Array(repeating: [], count: order.count)

		let number = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
		var seen: Set<Int> = []
		for (premise, conclusion) in links {
			guard let from = number[premise], let to = number[conclusion], from < to else { continue }
			if seen.insert(from * order.count + to).inserted {
				arrows.append((from, to))
				premises[to].append(from)
				conclusions[from].append(to)
			}
		}
	}

	private static func snapped(_ x: Double) -> Double {
		(x / half).rounded() * half
	}

	// MARK: - Groups

	/// Each set of statements joined by links, then every statement with no links at all as one last group
	var groups: [[Int]] {
		var leader = Array(0 ..< count)
		func find(_ statement: Int) -> Int {
			var statement = statement
			while leader[statement] != statement {
				statement = leader[statement]
			}
			return statement
		}
		for arrow in arrows {
			let (a, b) = (find(arrow.premise), find(arrow.conclusion))
			leader[max(a, b)] = min(a, b)
		}

		var linked: [Int: [Int]] = [:]
		var loose: [Int] = []
		for statement in 0 ..< count {
			if premises[statement].isEmpty, conclusions[statement].isEmpty {
				loose.append(statement)
			} else {
				linked[find(statement), default: []].append(statement)
			}
		}

		let joined = linked.keys.sorted().compactMap { linked[$0] }
		return loose.isEmpty ? joined : joined + [loose]
	}

	// MARK: - Rows

	/// The group's rows, top to bottom. A layer is the longest chain of premises behind a statement, then anything with
	/// slack moves down next to what it feeds, which is how a lone premise ends up right above its conclusion instead of
	/// sending a long arrow past everything between. Moving a statement that has as many premises as conclusions changes
	/// no arrow's length overall, but lets the statements above it follow.
	func rows(of group: [Int]) -> [[Int]] {
		var layer = [Int](repeating: 0, count: count)
		for statement in group {
			layer[statement] = premises[statement].map { layer[$0] + 1 }.max() ?? 0
		}
		for statement in group.reversed() where !conclusions[statement].isEmpty && conclusions[statement].count >= premises[statement].count {
			layer[statement] = (conclusions[statement].map { layer[$0] }.min() ?? 1) - 1
		}

		let layers = Dictionary(grouping: group) { layer[$0] }
		return layers.keys.sorted().flatMap { key -> [[Int]] in
			// Statements about the same things wrap together
			let sorted = (layers[key] ?? []).sorted { (closeness($0), $0) < (closeness($1), $1) }
			return stride(from: 0, to: sorted.count, by: CanvasLayout.maximumRowLength).map { start in
				Array(sorted[start ..< min(start + CanvasLayout.maximumRowLength, sorted.count)])
			}
		}
	}

	private func closeness(_ statement: Int) -> Double {
		let neighbours = conclusions[statement] + premises[statement]
		return neighbours.isEmpty ? Double(statement) : Double(neighbours.reduce(0, +)) / Double(neighbours.count)
	}

	// MARK: - Columns

	/// Where each statement in `rows` goes across, indexed by statement. Sweeps down and up the rows, with each row
	/// settling around what's linked to it on the side just placed, and keeps the sweep that scored best.
	func columns(for rows: [[Int]]) -> [Double] {
		var rowOf = [Int](repeating: -1, count: count)
		for (index, row) in rows.enumerated() {
			for statement in row {
				rowOf[statement] = index
			}
		}
		let arrows = arrows.filter { rowOf[$0.premise] >= 0 }

		var across = [Double](repeating: 0, count: count)
		var best = across
		var bestScore = Double.infinity

		for sweep in 0 ..< Self.sweeps {
			let down = sweep % 2 == 0
			for index in down ? Array(rows.indices) : rows.indices.reversed() {
				let wanted = Dictionary(uniqueKeysWithValues: rows[index].map { statement -> (Int, Double) in
					let (first, second) = down ? (premises[statement], conclusions[statement]) : (conclusions[statement], premises[statement])
					let neighbours = first.isEmpty ? second : first
					return (statement, neighbours.isEmpty ? across[statement] : neighbours.map { across[$0] }.reduce(0, +) / Double(neighbours.count))
				})
				let row = rows[index].sorted { (wanted[$0] ?? 0, $0) < (wanted[$1] ?? 0, $1) }
				let passing = arrows.filter { rowOf[$0.premise] < index && index < rowOf[$0.conclusion] }.map { Self.reach(of: $0, across: across, rowOf: rowOf, at: index) }
				let slots = Self.slots(wanted: row.map { wanted[$0] ?? 0 }, passing: passing)
				for (statement, slot) in zip(row, slots) {
					across[statement] = slot
				}
			}

			let score = Self.score(arrows: arrows, rows: rows, rowOf: rowOf, across: across)
			if score < bestScore {
				bestScore = score
				best = across
			}
		}

		return Self.cleared(best, arrows: arrows, rows: rows, rowOf: rowOf)
	}

	/// Sweeps aim for averages, which can leave a box on an arrow that skips its row. For each one left, tries moving the
	/// box or either end of the arrow a few steps along, and keeps whichever scores best.
	private static func cleared(_ across: [Double], arrows: [Arrow], rows: [[Int]], rowOf: [Int]) -> [Double] {
		var across = across
		var bestScore = score(arrows: arrows, rows: rows, rowOf: rowOf, across: across)

		for _ in 0 ..< repairPasses {
			var moved = false
			for arrow in arrows where rowOf[arrow.conclusion] - rowOf[arrow.premise] > 1 {
				for row in rowOf[arrow.premise] + 1 ..< rowOf[arrow.conclusion] {
					let passing = [reach(of: arrow, across: across, rowOf: rowOf, at: row)]
					for box in rows[row] where isBlocked(across[box], by: passing) {
						for statement in [box, arrow.conclusion, arrow.premise] {
							let home = across[statement]
							var bestSlot = home
							for step in 1 ... repairReach {
								for slot in [home - Double(step) * half, home + Double(step) * half] {
									let isFree = rows[rowOf[statement]].allSatisfy { $0 == statement || abs(across[$0] - slot) >= CanvasLayout.columnPitch }
									guard isFree else { continue }
									across[statement] = slot
									let score = score(arrows: arrows, rows: rows, rowOf: rowOf, across: across)
									if score < bestScore {
										bestScore = score
										bestSlot = slot
									}
								}
							}
							across[statement] = bestSlot
							moved = moved || bestSlot != home
						}
					}
				}
			}
			if !moved {
				break
			}
		}

		return across
	}

	/// The best slots for one row's boxes, left to right. Tries the whole row at each offset, and moves a box along when
	/// it would land on an arrow passing through, or on the box before it.
	private static func slots(wanted: [Double], passing: [ClosedRange<Double>]) -> [Double] {
		var best: [Double] = []
		var bestCost = Double.infinity

		for offset in -searchReach ... searchReach {
			var slots: [Double] = []
			var cost = 0.0
			for want in wanted {
				var slot = slots.last.map { max($0 + CanvasLayout.columnPitch, snapped(want)) } ?? snapped(want) + Double(offset) * half
				for _ in 0 ..< searchReach where isBlocked(slot, by: passing) {
					slot += half
				}
				if isBlocked(slot, by: passing) {
					cost += hitCost
				}
				let distance = (slot - want) / CanvasLayout.columnPitch
				cost += distance * distance
				slots.append(slot)
			}
			if cost < bestCost {
				bestCost = cost
				best = slots
			}
		}

		return best
	}

	/// Leaves room for the box and the arrow to each lean towards the other by a `jiggle`
	private static func isBlocked(_ slot: Double, by passing: [ClosedRange<Double>]) -> Bool {
		let clearance = CanvasLayout.boxSize.width / 2 + 2 * CanvasLayout.jiggle
		return passing.contains { slot + clearance > $0.lowerBound && slot - clearance < $0.upperBound }
	}

	/// How far across an arrow runs over the height of a box in row `row`
	private static func reach(of arrow: Arrow, across: [Double], rowOf: [Int], at row: Int) -> ClosedRange<Double> {
		let (fromRow, toRow) = (Double(rowOf[arrow.premise]), Double(rowOf[arrow.conclusion]))
		let slant = (across[arrow.conclusion] - across[arrow.premise]) / (toRow - fromRow)
		let middle = across[arrow.premise] + slant * (Double(row) - fromRow)
		let spread = abs(slant) * (CanvasLayout.boxSize.height / 2) / CanvasLayout.rowPitch
		return middle - spread ... middle + spread
	}

	/// Lower is better. Arrows through boxes, then crossings, then how far arrows slant, with big slants costing the most.
	private static func score(arrows: [Arrow], rows: [[Int]], rowOf: [Int], across: [Double]) -> Double {
		var score = 0.0
		for (index, arrow) in arrows.enumerated() {
			let slant = (across[arrow.conclusion] - across[arrow.premise]) / CanvasLayout.columnPitch
			score += slant * slant

			for row in rowOf[arrow.premise] + 1 ..< max(rowOf[arrow.conclusion], rowOf[arrow.premise] + 1) {
				let passing = [reach(of: arrow, across: across, rowOf: rowOf, at: row)]
				score += hitCost * Double(rows[row].count { isBlocked(across[$0], by: passing) })
			}

			for other in arrows[(index + 1)...] where crosses(arrow, other, rowOf: rowOf, across: across) {
				score += crossingCost
			}
		}
		return score
	}

	/// Whether two arrows cross on the way between their boxes. Arrows sharing a box don't.
	private static func crosses(_ a: Arrow, _ b: Arrow, rowOf: [Int], across: [Double]) -> Bool {
		guard a.premise != b.premise, a.premise != b.conclusion, a.conclusion != b.premise, a.conclusion != b.conclusion else { return false }
		guard rowOf[a.premise] < rowOf[b.conclusion], rowOf[b.premise] < rowOf[a.conclusion] else { return false }

		func side(_ arrow: Arrow, of statement: Int) -> Double {
			let (dx, dy) = (across[arrow.conclusion] - across[arrow.premise], Double(rowOf[arrow.conclusion] - rowOf[arrow.premise]))
			return dx * Double(rowOf[statement] - rowOf[arrow.premise]) - dy * (across[statement] - across[arrow.premise])
		}
		return side(a, of: b.premise) * side(a, of: b.conclusion) < 0 && side(b, of: a.premise) * side(b, of: a.conclusion) < 0
	}
}
