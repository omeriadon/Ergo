//
//  Board.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import Foundation

/// One board: statements holding English, joined by "premise of" links, and sources they can be broken down from.
///
/// It always holds at least one statement or source, so the Board tab is never empty.
struct Board: Codable, Hashable, Identifiable, Defaults.Serializable {
	var id = UUID()
	var created = Date.now
	var modified = Date.now

	var statements = [Statement()]
	var links: [Link] = []
	var sources: [BoardSource] = []

	/// Nothing written yet, so the board stays out of the list. Where boxes sit isn't writing.
	var isEmpty: Bool {
		sources.isEmpty && hasOnlyPlaceholder
	}

	/// No cards but the empty one a new board starts with, which something added can replace
	var hasOnlyPlaceholder: Bool {
		links.isEmpty && statements.allSatisfy(\.isEmpty)
	}

	/// The statements and links as `ErgoLogic` works with them: its validator, layout, text conversions and checks
	var map: ArgumentMap<Statement, Link> {
		get {
			ArgumentMap(statements: statements, links: links)
		}
		set {
			statements = newValue.statements
			links = newValue.links
		}
	}

	func statement(_ id: Statement.ID) -> Statement? {
		statements.first { $0.id == id }
	}

	func source(_ id: BoardSource.ID) -> BoardSource? {
		sources.first { $0.id == id }
	}

	// MARK: - Regions

	func members(of source: BoardSource.ID) -> [Statement] {
		statements.filter { $0.source == source }
	}

	/// The shape around a source and its cards, leaving out the card being placed when working out where it belongs
	func outline(of source: BoardSource, without leaving: Statement.ID? = nil) -> [CanvasPoint] {
		let members = members(of: source.id).filter { $0.id != leaving }
		let positions = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.position) })
		let arrows = links.compactMap { link -> CanvasRegion.Arrow? in
			guard let from = positions[link.premise], let to = positions[link.conclusion] else { return nil }
			return CanvasRegion.Arrow(from: from, to: to)
		}
		return CanvasRegion.outline(source: source.position, members: members.map(\.position), arrows: arrows)
	}

	/// The region a card belongs to once it's at its position
	func home(of statement: Statement) -> BoardSource.ID? {
		let outlines = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, outline(of: $0, without: statement.id)) })
		return CanvasRegion.home(of: statement.position, current: statement.source, outlines: outlines)
	}

	/// Everything that takes up room, for fitting the canvas to it
	var occupiedRects: [CanvasRect] {
		var rects = statements.map { CanvasRect(center: $0.position, size: CanvasLayout.boxSize) }
		rects += sources.map { CanvasRect(center: $0.position, size: CanvasLayout.boxSize) }
		for source in sources where !members(of: source.id).isEmpty {
			rects += outline(of: source).map { CanvasRect(center: $0, size: CanvasSize(width: 0, height: 0)) }
		}
		return rects
	}

	/// Sets the sources back on their cards after the cards moved, and clear of anything else. Ones without cards only
	/// move if something landed on them.
	mutating func settleSources() {
		var occupied = statements.map(\.position)
		for index in sources.indices {
			let cards = members(of: sources[index].id).map(\.position)
			let wanted = CanvasRegion.sourcePosition(above: cards) ?? sources[index].position
			let box = CanvasRect(center: wanted, size: CanvasLayout.boxSize)
			let isClear = !occupied.contains { box.intersects(CanvasRect(center: $0, size: CanvasLayout.boxSize), margin: CanvasLayout.minimumGap) }
			sources[index].position = isClear ? wanted : CanvasLayout.place(near: wanted, side: cards.isEmpty ? .below : .above, occupied: occupied)
			occupied.append(sources[index].position)
		}
	}

	/// The first English in reading order, else "Untitled"
	var title: String {
		map.topologicalOrder().lazy
			.compactMap { statement($0)?.englishLine }
			.first ?? sources.first?.title ?? "Untitled"
	}
}
