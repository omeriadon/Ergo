//
//  CanvasBoard.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// The boxes and arrows of a page, in canvas units. A box being dragged is kept here, so each frame of a drag redraws
/// only this view and not the canvas around it with its bars and toolbar. The page only hears about it when the finger lifts.
struct CanvasBoard: View {
	private struct BoxDrag {
		let id: Statement.ID
		let origin: CanvasPoint
		let before: CanvasHistory.Snapshot?
		var translation: CGSize
	}

	let page: LogicPage
	let letters: [String]
	let relations: [Statement.ID: BoxRelations]
	let verdicts: [Statement.ID: BoxVerdict]
	let selectedStatement: Statement.ID?
	let selectedLink: Link.ID?

	/// Turns a finger's travel on screen into canvas units
	let scale: CGFloat

	let history: CanvasHistory
	let zoomNamespace: Namespace.ID
	let appearance: (Statement.ID) -> BoxAppearance
	let actions: (Statement) -> BoxActions
	let dragStarted: (Statement.ID) -> Void

	/// The finger lifted, with where the box ended up and the page as it was before the drag
	let moved: (Statement.ID, CanvasPoint, CanvasHistory.Snapshot?) -> Void

	@State private var drag: BoxDrag?

	/// Where each box is drawn: the page's position, or where its finger has taken it
	private var positions: [Statement.ID: CanvasPoint] {
		var positions = Dictionary(page.statements.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })
		if let drag {
			positions[drag.id] = position(of: drag)
		}
		return positions
	}

	var body: some View {
		let positions = positions

		// Arrows first, so boxes sit on top
		ZStack {
			LinkLayer(links: page.links, positions: positions, selected: selectedLink)

			ForEach(page.statements) { statement in
				box(statement, at: positions[statement.id] ?? statement.position)
					.zIndex(zIndex(of: statement.id))
					.transition(.opacity)
			}
		}
	}

	private func box(_ statement: Statement, at position: CanvasPoint) -> some View {
		CanvasBox(
			statement: statement,
			letters: letters,
			descriptors: page.descriptors,
			relations: relations[statement.id] ?? BoxRelations(),
			verdict: verdicts[statement.id],
			appearance: appearance(statement.id),
			isDragging: drag?.id == statement.id,
			position: position,
			zoomNamespace: zoomNamespace,
			actions: actions(statement),
			dragChanged: { dragChanged(statement, $0) },
			dragEnded: { dragEnded(statement.id, $0) }
		)
	}

	private func zIndex(of id: Statement.ID) -> Double {
		if drag?.id == id {
			return 2
		}
		return selectedStatement == id ? 1 : 0
	}

	private func position(of drag: BoxDrag) -> CanvasPoint {
		CanvasGrid.snapped(CanvasPoint(
			x: drag.origin.x + drag.translation.width / scale,
			y: drag.origin.y + drag.translation.height / scale
		))
	}

	private func dragChanged(_ statement: Statement, _ translation: CGSize) {
		if drag?.id == statement.id {
			drag?.translation = translation
		} else {
			dragStarted(statement.id)
			drag = BoxDrag(id: statement.id, origin: statement.position, before: history.snapshot(), translation: translation)
		}
	}

	private func dragEnded(_ id: Statement.ID, _ translation: CGSize) {
		guard var finished = drag, finished.id == id else { return }
		finished.translation = translation
		drag = nil
		moved(id, position(of: finished), finished.before)
	}
}
