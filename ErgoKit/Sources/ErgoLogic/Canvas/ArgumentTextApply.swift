//
//  ArgumentTextApply.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

/// The map after applying text, and what changed in it
public struct ArgumentTextChange<Node: ArgumentNode, Link: ArgumentLink>: Sendable {
	public var map: ArgumentMap<Node, Link>

	/// Kept statements whose content changed. Their other field (the English of edited logic, and the other way round) is stale.
	public var edited: Set<UUID>

	/// New statements, in text order
	public var added: [UUID]

	/// Deleted statements. Their links went with them.
	public var removed: Set<UUID>
}

extension ArgumentText {
	/// Matches the lines of `text` to the map's statements and returns the map they describe.
	///
	/// 1. Lines are compared with the statements in `order(of:kind:)`. Lines that match a statement exactly keep it,
	///    and the longest run of such lines is kept in order. Moving a line counts as deleting and adding it.
	/// 2. Between those, leftover lines and leftover statements are paired in order: the line replaces the statement's
	///    content, and the statement keeps its id, position and links. Extra lines become new statements, extra statements are deleted.
	/// 3. A conclusion line is paired with the map's conclusion directly, however much it changed.
	/// 4. A new statement goes beside the conclusion and becomes its premise. If the conclusion had no premises yet,
	///    every line above it becomes one (unless that would loop).
	///
	/// Statements with no content of this kind (a box still being written) are untouched.
	public static func apply<Node, Link>(
		text: String,
		kind: ArgumentTextKind,
		letters: [String] = LogicLetters.defaults,
		to map: ArgumentMap<Node, Link>,
		maximumStatements: Int = ArgumentMapValidator.defaultMaximumStatements,
		makeID: () -> UUID = { UUID() }
	) throws(ArgumentTextProblem) -> ArgumentTextChange<Node, Link> {
		switch kind {
			case .english:
				return try apply(draft(english: text), kind: .english, to: map, maximumStatements: maximumStatements, makeID: makeID)
			case .logic:
				let entries = LogicInputVocabulary(letters: letters).entries(in: text)
				return try apply(entries: entries, to: map, maximumStatements: maximumStatements, makeID: makeID)
		}
	}

	/// Logic text that is already entries, as the editor holds it
	public static func apply<Node, Link>(
		entries: [LogicKeyboardEntry],
		to map: ArgumentMap<Node, Link>,
		maximumStatements: Int = ArgumentMapValidator.defaultMaximumStatements,
		makeID: () -> UUID = { UUID() }
	) throws(ArgumentTextProblem) -> ArgumentTextChange<Node, Link> {
		try apply(draft(logic: entries), kind: .logic, to: map, maximumStatements: maximumStatements, makeID: makeID)
	}

	// MARK: - Applying

	private static func apply<Node, Link>(
		_ draft: Draft,
		kind: ArgumentTextKind,
		to map: ArgumentMap<Node, Link>,
		maximumStatements: Int,
		makeID: () -> UUID
	) throws(ArgumentTextProblem) -> ArgumentTextChange<Node, Link> {
		let order = order(of: map, kind: kind)
		let lines = draft.premises + (draft.conclusion.map { [$0] } ?? [])
		let conclusionLine = draft.conclusion == nil ? nil : lines.count - 1

		let total = map.statements.count - order.statements.count + lines.count
		if total > maximumStatements, total > map.statements.count {
			throw .tooManyStatements(limit: maximumStatements, found: total)
		}

		var byID: [UUID: Node] = [:]
		for statement in map.statements where byID[statement.id] == nil {
			byID[statement.id] = statement
		}
		let old = order.statements.map { ArgumentContent(of: byID[$0]!, kind).normalized }
		let new = lines.map(\.normalized)

		var match: [Int?] = if conclusionLine != nil, order.conclusion != nil {
			align(old: Array(old.dropLast()), new: Array(new.dropLast())) + [old.count - 1]
		} else {
			align(old: old, new: new)
		}

		var change = ArgumentTextChange(map: map, edited: [], added: [], removed: [])

		// Deleted statements take their links with them
		let kept = Set(match.compactMap(\.self))
		for (index, id) in order.statements.enumerated() where !kept.contains(index) {
			change.removed.insert(id)
		}
		change.map.statements.removeAll { change.removed.contains($0.id) }
		change.map.links.removeAll { change.removed.contains($0.premise) || change.removed.contains($0.conclusion) }

		// Edits keep identity, so only content that really changed is written
		var lineIDs: [UUID] = []
		var fresh: [Int] = []
		for (line, matched) in match.enumerated() {
			guard let matched else {
				lineIDs.append(makeID())
				fresh.append(line)
				continue
			}
			let id = order.statements[matched]
			lineIDs.append(id)
			if old[matched] != new[line], let index = change.map.statements.firstIndex(where: { $0.id == id }) {
				lines[line].write(to: &change.map.statements[index])
				change.edited.insert(id)
			}
		}

		let target = conclusionLine.map { lineIDs[$0] }
		let hadPremises = target.map { map.isConclusion($0) } ?? false

		// Links: new lines become premises of the conclusion, and so do old ones if it had none
		if let target {
			for line in lines.indices where line != conclusionLine {
				let id = lineIDs[line]
				guard match[line] == nil || !hadPremises,
				      !change.map.links.contains(where: { $0.premise == id && $0.conclusion == target }),
				      !change.map.reaches(target, id)
				else { continue }
				change.map.links.append(Link(id: makeID(), premise: id, conclusion: target))
			}
		}

		// Positions, then the new statements in text order
		let positions = positions(
			forNew: fresh,
			target: target.map { id in (id, conclusionLine.map { match[$0] == nil } ?? false) },
			lineIDs: lineIDs,
			in: change.map,
			order: order,
			emptyBefore: map.statements.isEmpty
		)

		for line in fresh {
			var node = Node(id: lineIDs[line], position: positions[lineIDs[line]] ?? .zero, english: "", logic: [])
			lines[line].write(to: &node)
			change.map.statements.append(node)
			change.added.append(node.id)
		}

		// With nothing to sit beside, the whole map is laid out
		if map.statements.isEmpty {
			change.map = CanvasLayout.arranged(change.map)
		}

		return change
	}

	/// Where each new statement goes. A new conclusion goes right of the rightmost statement above it,
	/// and new premises go left of the conclusion.
	private static func positions(
		forNew fresh: [Int],
		target: (id: UUID, isNew: Bool)?,
		lineIDs: [UUID],
		in map: ArgumentMap<some Any, some Any>,
		order: Order,
		emptyBefore: Bool
	) -> [UUID: CanvasPoint] {
		guard !emptyBefore, !fresh.isEmpty else { return [:] }

		var occupied = map.statements.map(\.position)
		var result: [UUID: CanvasPoint] = [:]

		func place(near anchor: CanvasPoint, _ side: CanvasLayout.Side, for id: UUID) {
			let spot = CanvasLayout.place(near: anchor, side: side, occupied: occupied)
			occupied.append(spot)
			result[id] = spot
		}

		let survivors = order.statements.compactMap { map.statement($0)?.position }
		var anchor = survivors.max { $0.x < $1.x } ?? survivors.last ?? .zero

		if let target, target.isNew {
			place(near: anchor, .right, for: target.id)
			anchor = result[target.id] ?? anchor
		} else if let target, let position = map.statement(target.id)?.position {
			anchor = position
		}

		let side: CanvasLayout.Side = target == nil ? .below : .left
		for line in fresh where lineIDs[line] != target?.id {
			place(near: anchor, side, for: lineIDs[line])
		}
		return result
	}

	/// For each new line, the index of the old statement it matches, nil if it has none
	private static func align(old: [ArgumentContent], new: [ArgumentContent]) -> [Int?] {
		let count = (old: old.count, new: new.count)
		var length = [[Int]](repeating: [Int](repeating: 0, count: count.new + 1), count: count.old + 1)
		for i in stride(from: count.old - 1, through: 0, by: -1) {
			for j in stride(from: count.new - 1, through: 0, by: -1) {
				length[i][j] = old[i] == new[j] ? length[i + 1][j + 1] + 1 : max(length[i + 1][j], length[i][j + 1])
			}
		}

		var anchors: [(old: Int, new: Int)] = []
		var i = 0
		var j = 0
		while i < count.old, j < count.new {
			if old[i] == new[j] {
				anchors.append((i, j))
				i += 1
				j += 1
			} else if length[i + 1][j] >= length[i][j + 1] {
				i += 1
			} else {
				j += 1
			}
		}

		var match = [Int?](repeating: nil, count: count.new)
		var previous = (old: -1, new: -1)
		for anchor in anchors + [(old: count.old, new: count.new)] {
			let oldGap = previous.old + 1 ..< anchor.old
			let newGap = previous.new + 1 ..< anchor.new
			for step in 0 ..< min(oldGap.count, newGap.count) {
				match[newGap.lowerBound + step] = oldGap.lowerBound + step
			}
			if anchor.new < count.new {
				match[anchor.new] = anchor.old
			}
			previous = anchor
		}
		return match
	}
}
