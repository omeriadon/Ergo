//
//  CanvasBoardView+Boxes.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoSync
import SwiftUI
import UIKit

extension CanvasBoardView {
	// MARK: - Boxes

	func addCell(for model: CanvasBoxModel, isNew: Bool) {
		let cell = CanvasBoxCell(model: model, isNew: isNew, content: boxContent)
		content.addSubview(cell)
		let id = model.statement.id
		cell.openComment = { [weak self] in self?.showAnalysis(.statement(id)) }

		let drag = UIPanGestureRecognizer(target: self, action: #selector(boxPanned))
		drag.maximumNumberOfTouches = 1
		drag.delegate = self
		cell.addGestureRecognizer(drag)

		cells[id] = cell
	}

	func remove(_ cell: UIView, animated: Bool) {
		guard animated else {
			cell.removeFromSuperview()
			return
		}
		UIView.animate(withDuration: 0.2) {
			cell.alpha = 0
		} completion: { _ in
			cell.removeFromSuperview()
		}
	}

	/// Follows the finger exactly, and only settles on the grid when it lifts
	@objc func boxPanned(_ recognizer: UIPanGestureRecognizer) {
		guard let cell = recognizer.view as? CanvasBoxCell else { return }
		let id = cell.model.statement.id

		switch recognizer.state {
			case .began:
				stopGlide()
				draggedBox = (id, cell.center)
				content.bringSubviewToFront(cell)
				cell.isLifted = true
				gridPoint = CanvasGrid.snapped(CanvasPoint(cell.center))
				haptics.prepare()
				updateHandles()
				dragStarted(id)

			case .changed:
				guard let draggedBox, draggedBox.id == id else { return }
				let travel = recognizer.translation(in: content)
				cell.center = CGPoint(x: draggedBox.origin.x + travel.x, y: draggedBox.origin.y + travel.y)
				updateArrows(touching: id, animation: nil)
				updateRegion(holding: id, animation: nil)
				feelGrid(at: cell.center)

			case .ended, .cancelled, .failed:
				guard let draggedBox, draggedBox.id == id else { return }
				self.draggedBox = nil
				gridPoint = nil
				cell.isLifted = false

				let finished = recognizer.state == .ended
				let target = finished ? CanvasGrid.snapped(CanvasPoint(cell.center)) : CanvasPoint(draggedBox.origin)
				UIView.animate(springDuration: 0.25, bounce: 0) {
					cell.center = target.point
					updateHandles()
				}
				updateArrows(touching: id, animation: 0.25)
				updateRegion(holding: id, animation: 0.25)
				if finished {
					moved(id, target)
				}

			default:
				break
		}
	}

	// MARK: - Sources

	func addSourceCell(for model: CanvasSourceModel, isNew: Bool) {
		let cell = CanvasSourceCell(model: model, isNew: isNew, content: sourceContent)
		content.addSubview(cell)
		let id = model.source.id
		cell.openComment = { [weak self] in self?.showAnalysis(.source(id)) }

		let drag = UIPanGestureRecognizer(target: self, action: #selector(sourcePanned))
		drag.maximumNumberOfTouches = 1
		drag.delegate = self
		cell.addGestureRecognizer(drag)

		sourceCells[id] = cell
	}

	/// The source brings its region along: its cards follow the finger with it, and their arrows and the shape follow them
	@objc func sourcePanned(_ recognizer: UIPanGestureRecognizer) {
		guard let cell = recognizer.view as? CanvasSourceCell else { return }
		let id = cell.model.source.id

		switch recognizer.state {
			case .began:
				stopGlide()
				let members = regions.first { $0.source == id }?.members ?? []
				draggedSource = (id, cell.center, members.compactMap { member in cells[member].map { (member, $0.center) } })
				content.bringSubviewToFront(cell)
				cell.isLifted = true
				gridPoint = CanvasGrid.snapped(CanvasPoint(cell.center))
				haptics.prepare()
				updateHandles()
				sourceDragStarted(id)

			case .changed:
				guard let draggedSource, draggedSource.id == id else { return }
				let travel = recognizer.translation(in: content)
				moveHeldSource(draggedSource, by: travel)
				for member in draggedSource.members {
					updateArrows(touching: member.id, animation: nil)
				}
				updateRegion(of: id, animation: nil)
				feelGrid(at: cell.center)

			case .ended, .cancelled, .failed:
				guard let held = draggedSource, held.id == id else { return }
				draggedSource = nil
				gridPoint = nil
				cell.isLifted = false

				let finished = recognizer.state == .ended
				let travel = recognizer.translation(in: content)
				let current = CGPoint(x: held.origin.x + travel.x, y: held.origin.y + travel.y)
				let target = finished ? CanvasGrid.snapped(CanvasPoint(current)) : CanvasPoint(held.origin)
				let settled = CGPoint(x: target.x - held.origin.x, y: target.y - held.origin.y)
				UIView.animate(springDuration: 0.25, bounce: 0) {
					moveHeldSource(held, by: settled)
				}
				for member in held.members {
					updateArrows(touching: member.id, animation: 0.25)
				}
				updateRegion(of: id, animation: 0.25)
				if finished {
					sourceMoved(id, target)
				}

			default:
				break
		}
	}

	func moveHeldSource(_ held: (id: BoardSource.ID, origin: CGPoint, members: [(id: Statement.ID, origin: CGPoint)]), by travel: CGPoint) {
		sourceCells[held.id]?.center = CGPoint(x: held.origin.x + travel.x, y: held.origin.y + travel.y)
		for member in held.members {
			cells[member.id]?.center = CGPoint(x: member.origin.x + travel.x, y: member.origin.y + travel.y)
		}
	}
}
