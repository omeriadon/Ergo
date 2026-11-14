//
//  BoardOutlineView.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import ErgoLogic
import SwiftUI

/// A row of the outline. A statement can be listed more than once (a premise of two conclusions, or a card under its
/// source), so each place it's listed is its own item.
nonisolated enum BoardOutlineItem: Hashable {
	case statement(Statement.ID, place: Int)
	case source(BoardSource.ID)
}

/// The board as an indented list instead of the canvas: each argument's conclusion with its premises under it, from
/// `ArgumentOutline`, then the cards in no argument, then the sources with their cards. It only reads the board; opening
/// and deleting go back to `CanvasView`, which does them through `BoardStore` as the canvas does.
struct BoardOutlineView: View {
	let board: Board
	let isReadOnly: Bool
	let counts: [UUID: Int]
	let findHighlight: String?
	let open: (Statement.ID) -> Void
	let openSource: (BoardSource.ID) -> Void
	let delete: (Statement.ID) -> Void
	let deleteSource: (BoardSource.ID) -> Void

	@State private var selection: BoardOutlineItem?

	var body: some View {
		List(selection: $selection) {
			BoardOutlineSections(
				lines: BoardOutlineLines(board: board),
				board: board,
				counts: counts,
				findHighlight: findHighlight,
				canDelete: !isReadOnly,
				act: act
			)
		}
		.scrollContentBackground(.hidden)
		.contextMenu(forSelectionType: BoardOutlineItem.self, menu: menu, primaryAction: primaryAction)
		.accessibilityIdentifier("board.outline")
		#if os(macOS)
			// The Delete key, on the selected row
			.onDeleteCommand {
				if let selection {
					act(.delete, on: selection)
				}
			}
		#endif
	}

	// MARK: - Actions

	enum Action {
		case open, delete
	}

	private func act(_ action: Action, on item: BoardOutlineItem) {
		switch (action, item) {
			case let (.open, .statement(id, _)):
				open(id)
			case let (.open, .source(id)):
				openSource(id)
			case let (.delete, .statement(id, _)):
				if !isReadOnly {
					delete(id)
				}
			case let (.delete, .source(id)):
				if !isReadOnly {
					deleteSource(id)
				}
		}
	}

	/// A tap on iOS, and a double-click or Return on the Mac
	private func primaryAction(_ items: Set<BoardOutlineItem>) {
		if items.count == 1, let item = items.first {
			act(.open, on: item)
		}
	}

	@ViewBuilder
	private func menu(_ items: Set<BoardOutlineItem>) -> some View {
		if items.count == 1, let item = items.first {
			Button("Open", systemImage: "doc.text") {
				act(.open, on: item)
			}
			if !isReadOnly {
				Button("Delete", systemImage: "trash", role: .destructive) {
					act(.delete, on: item)
				}
			}
		}
	}
}

// MARK: - Lines

/// What the outline lists, worked out once per update
struct BoardOutlineLines {
	struct Line: Identifiable {
		let item: BoardOutlineItem
		let statement: Statement
		let depth: Int

		/// Listed in full further up
		let isRepeat: Bool

		/// Has premises listed under it
		let isConclusion: Bool

		var id: BoardOutlineItem {
			item
		}
	}

	struct SourceLines: Identifiable {
		let source: BoardSource
		let cards: [Line]

		var id: BoardSource.ID {
			source.id
		}
	}

	var arguments: [Line] = []
	var unlinked: [Line] = []
	var sources: [SourceLines] = []

	init(board: Board) {
		let outline = ArgumentOutline(board.map)
		var statements: [Statement.ID: Statement] = [:]
		for statement in board.statements where statements[statement.id] == nil {
			statements[statement.id] = statement
		}
		var place = 0
		func line(_ id: Statement.ID, depth: Int, isRepeat: Bool = false, isConclusion: Bool = false) -> Line? {
			guard let statement = statements[id] else { return nil }
			place += 1
			return Line(item: .statement(id, place: place), statement: statement, depth: depth, isRepeat: isRepeat, isConclusion: isConclusion)
		}

		// As the box shows it: anything with premises, even where they aren't repeated under it
		let conclusions = Set(board.links.lazy.filter { $0.premise != $0.conclusion }.map(\.conclusion))
		for row in outline.arguments.joined() {
			if let line = line(row.statement, depth: row.depth, isRepeat: row.isRepeat, isConclusion: conclusions.contains(row.statement)) {
				arguments.append(line)
			}
		}
		unlinked = outline.unlinked.compactMap { line($0, depth: 0) }

		// Cards under their source in the same reading order as the arguments
		let order = outline.arguments.flatMap { $0.map(\.statement) } + outline.unlinked
		var rank: [Statement.ID: Int] = [:]
		for (index, id) in order.enumerated() where rank[id] == nil {
			rank[id] = index
		}
		sources = board.sources.map { source in
			let members = board.members(of: source.id).map(\.id).sorted { rank[$0, default: 0] < rank[$1, default: 0] }
			return SourceLines(source: source, cards: members.compactMap { line($0, depth: 1, isConclusion: conclusions.contains($0)) })
		}
	}
}

// MARK: - Sections

private struct BoardOutlineSections: View {
	let lines: BoardOutlineLines
	let board: Board
	let counts: [UUID: Int]
	let findHighlight: String?
	let canDelete: Bool
	let act: (BoardOutlineView.Action, BoardOutlineItem) -> Void

	var body: some View {
		if !lines.arguments.isEmpty {
			Section("Arguments") {
				ForEach(lines.arguments) { line in
					row(line)
				}
			}
		}

		if !lines.unlinked.isEmpty {
			Section(lines.arguments.isEmpty ? "Statements" : "Other Statements") {
				ForEach(lines.unlinked) { line in
					row(line)
				}
			}
		}

		if !lines.sources.isEmpty {
			Section("Sources") {
				ForEach(lines.sources) { source in
					BoardOutlineSourceRow(source: source.source, annotationCount: counts[source.source.id] ?? 0)
						.tag(BoardOutlineItem.source(source.source.id))
						.modifier(BoardOutlineDelete(item: .source(source.source.id), canDelete: canDelete, act: act))
					ForEach(source.cards) { line in
						row(line)
					}
				}
			}
		}
	}

	private func row(_ line: BoardOutlineLines.Line) -> some View {
		BoardOutlineRow(line: line, annotationCount: counts[line.statement.id] ?? 0, findHighlight: findHighlight)
			.tag(line.item)
			.modifier(BoardOutlineDelete(item: line.item, canDelete: canDelete, act: act))
	}
}

/// Swiping a row away, on a board this person can edit
private struct BoardOutlineDelete: ViewModifier {
	let item: BoardOutlineItem
	let canDelete: Bool
	let act: (BoardOutlineView.Action, BoardOutlineItem) -> Void

	func body(content: Content) -> some View {
		content.swipeActions(edge: .trailing) {
			if canDelete {
				Button("Delete", systemImage: "trash", role: .destructive) {
					act(.delete, item)
				}
			}
		}
	}
}

// MARK: - Rows

/// A card's English as its box shows it, indented under the conclusion it supports
private struct BoardOutlineRow: View {
	static let indent: CGFloat = 18

	let line: BoardOutlineLines.Line
	let annotationCount: Int
	let findHighlight: String?

	/// The English, else the box's prompt
	private var headline: (text: String, isPlaceholder: Bool) {
		let english = line.statement.english.trimmingCharacters(in: .whitespacesAndNewlines)
		return english.isEmpty ? ("Empty statement", true) : (english, false)
	}

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 8) {
			Text(line.isConclusion ? "∴" : "•")
				.font(.callout.weight(.semibold))
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)

			Text(AttributedString(headline.text).findHighlighted(headline.isPlaceholder ? nil : findHighlight))
				.foregroundStyle(headline.isPlaceholder ? .secondary : .primary)
				.lineLimit(4)
				.frame(maxWidth: .infinity, alignment: .leading)

			if line.isRepeat {
				Image(systemName: "arrow.turn.left.up")
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityLabel("Listed above")
			}

			AnnotationBadge(count: annotationCount)
		}
		.padding(.leading, CGFloat(line.depth) * Self.indent)
		.contentShape(Rectangle())
		.accessibilityElement(children: .combine)
		.accessibilityValue(line.isConclusion ? "Conclusion" : (line.depth > 0 ? "Premise, level \(line.depth)" : ""))
	}
}

private struct BoardOutlineSourceRow: View {
	let source: BoardSource
	let annotationCount: Int

	var body: some View {
		HStack(spacing: 8) {
			Label(source.title, systemImage: source.link == nil ? "doc.text" : "safari")
				.lineLimit(2)
				.frame(maxWidth: .infinity, alignment: .leading)

			AnnotationBadge(count: annotationCount)
		}
		.font(.body.weight(.medium))
		.contentShape(Rectangle())
	}
}
