//
//  CanvasView+Boxes.swift
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
	// MARK: - Appearance

	func appearance(of id: Statement.ID, connectable: Set<Statement.ID>?) -> BoxAppearance {
		if let connectable {
			if id == linkSource {
				return .connectSource
			}
			guard connectable.contains(id) else {
				return .unavailable
			}
			return id == connectTarget ? .selected : .normal
		}
		return activeSelection == .statement(id) ? .selected : .normal
	}

	/// Titles of what each box is joined to, for its ∴ mark and for VoiceOver
	var boxRelations: [Statement.ID: BoxRelations] {
		let board = board
		let titles = Dictionary(board.statements.map { ($0.id, StatementBoxView.title(of: $0)) }, uniquingKeysWith: { first, _ in first })

		var relations: [Statement.ID: BoxRelations] = [:]
		for link in board.links where link.premise != link.conclusion {
			guard let premise = titles[link.premise], let conclusion = titles[link.conclusion] else { continue }
			relations[link.conclusion, default: BoxRelations()].premises.append(premise)
			relations[link.premise, default: BoxRelations()].conclusions.append(conclusion)
		}
		return relations
	}

	/// While drawing an arrow, the boxes it could end at, and while removing one, the boxes it could be going to.
	/// Nil when doing neither.
	var connectableStatements: Set<Statement.ID>? {
		if case let .unlink(id) = activePick {
			return Set(board.links.filter { $0.premise == id }.map(\.conclusion) + board.links.filter { $0.conclusion == id }.map(\.premise))
		}
		guard let linkSource else { return nil }
		let map = board.map
		return Set(board.statements.map(\.id).filter { target in
			ArgumentMapValidator.problem(adding: newLink(from: linkSource, to: target), to: map) == nil
		})
	}

	/// The box an arrow is coming out of, by dragging or by picking
	var linkSource: Statement.ID? {
		connecting ?? activePick?.source
	}

	/// A pick whose box is gone (deleted here, or on another device) is no pick
	var activePick: BoxPick? {
		guard !isReadOnly else { return nil }
		return pick.flatMap { board.statement($0.source) == nil ? nil : $0 }
	}

	/// A selection that's gone (deleted here, or on another device) is no selection
	var activeSelection: CanvasSelection? {
		switch selection {
			case let .statement(id)?:
				board.statement(id) == nil ? nil : selection
			case let .link(id)?:
				board.links.contains { $0.id == id } ? selection : nil
			case let .source(id)?:
				board.source(id) == nil ? nil : selection
			case nil:
				nil
		}
	}

	// MARK: - Box actions

	func actions(for statement: Statement) -> BoxActions {
		let id = statement.id
		return BoxActions(
			select: { select(id) },
			edit: { edit(id) },
			delete: { delete(id) },
			connect: { pickToConnect(id, asConclusion: $0) },
			removeLink: { pickToUnlink(id) },
			showAnalysis: { showAnalysis(of: .statement(id)) },
			nudge: { nudge(id, columns: $0, rows: $1) }
		)
	}

	func sourceActions(for source: BoardSource) -> SourceActions {
		let id = source.id
		return SourceActions(
			select: { selectSource(id) },
			open: { open(id) },
			edit: { sourceSheet = .edit(id) },
			breakDown: { navigation.presentSheet(.breakDownSource(id)) },
			delete: { deleteSource(id) },
			showAnalysis: { showAnalysis(of: .source(id)) },
			nudge: { nudgeSource(id, columns: $0, rows: $1) }
		)
	}

	func select(_ id: Statement.ID) {
		if let activePick {
			finish(activePick, with: id)
		} else {
			selection = .statement(id)
		}
	}

	func edit(_ id: Statement.ID) {
		pick = nil
		selection = .statement(id)
		// The card leaves the bars where they are, behind it
		isCovered = !usesEditorCard
		editing = id
	}

	func dragStarted(_ id: Statement.ID) {
		pick = nil
		selection = .statement(id)
		dragBefore = history.snapshot()
	}

	func boxMoved(_ id: Statement.ID, to position: CanvasPoint) {
		boardStore.moveStatement(id: id, to: position)
		history.register(dragBefore, name: "Move Statement")
		dragBefore = nil
	}

	/// For VoiceOver, which can't drag: a step of the grid at a time
	func nudge(_ id: Statement.ID, columns: Int, rows: Int) {
		guard let statement = board.statement(id) else { return }
		let target = CanvasGrid.snapped(CanvasPoint(
			x: statement.position.x + Double(columns) * CanvasGrid.step,
			y: statement.position.y + Double(rows) * CanvasGrid.step
		))
		history.perform("Move Statement") {
			boardStore.moveStatement(id: id, to: target)
		}
	}
}
