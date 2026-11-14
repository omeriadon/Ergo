//
//  CanvasBoardView+Boxes+AppKit.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

#if os(macOS)
	import AppKit
	import ErgoLogic
	import ErgoSync
	import SwiftUI

	extension CanvasBoardView {
		// MARK: - Boxes

		func addCell(for model: CanvasBoxModel, isNew: Bool) {
			let cell = CanvasBoxCell(model: model, isNew: isNew, content: boxContent)
			content.addSubview(cell)
			let id = model.statement.id
			cell.openComment = { [weak self] in self?.showAnalysis(.statement(id)) }
			cell.addGestureRecognizer(makeDrag(#selector(boxPanned)))
			cells[id] = cell
		}

		func remove(_ view: NSView, animated: Bool) {
			guard animated else {
				view.removeFromSuperview()
				return
			}
			NSAnimationContext.animate(.easeOut(duration: 0.2)) {
				view.animator().alphaValue = 0
			} completion: {
				view.removeFromSuperview()
			}
		}

		/// A drag with the primary button. It doesn't hold back the click, so SwiftUI's taps in the box still arrive.
		func makeDrag(_ action: Selector) -> NSPanGestureRecognizer {
			let drag = NSPanGestureRecognizer(target: self, action: action)
			drag.buttonMask = 0x1
			drag.delegate = self
			return drag
		}

		/// Follows the pointer exactly, and only settles on the grid when it lets go
		@objc func boxPanned(_ recognizer: NSPanGestureRecognizer) {
			guard let cell = recognizer.view as? CanvasBoxCell else { return }
			let id = cell.model.statement.id

			// A box on a board that can only be viewed moves the canvas instead, as the background would
			if isReadOnly {
				panCanvas(with: recognizer)
				return
			}

			switch recognizer.state {
				case .began:
					draggedBox = (id, cell.center)
					bringToFront(cell)
					cell.isLifted = true
					gridPoint = CanvasGrid.snapped(CanvasPoint(cell.center))
					updateHandles()
					NSCursor.closedHand.set()
					dragStarted(id)

				case .changed:
					guard let draggedBox, draggedBox.id == id else { return }
					let travel = recognizer.translation(in: content)
					cell.center = CGPoint(x: draggedBox.origin.x + travel.x, y: draggedBox.origin.y + travel.y)
					updateArrows(touching: id, animation: nil)
					updateRegion(holding: id, animation: nil)
					gridPoint = CanvasGrid.snapped(CanvasPoint(cell.center))

				case .ended, .cancelled, .failed:
					guard let draggedBox, draggedBox.id == id else { return }
					self.draggedBox = nil
					gridPoint = nil
					cell.isLifted = false

					let finished = recognizer.state == .ended
					let target = finished ? CanvasGrid.snapped(CanvasPoint(cell.center)) : CanvasPoint(draggedBox.origin)
					NSAnimationContext.animate(.spring(duration: 0.25, bounce: 0)) {
						cell.setCenter(target.point, animated: true)
					}
					updateArrows(touching: id, animation: 0.25)
					updateRegion(holding: id, animation: 0.25)
					updateHandles()
					updateCursor(at: recognizer.location(in: self))
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
			cell.addGestureRecognizer(makeDrag(#selector(sourcePanned)))
			sourceCells[id] = cell
		}

		/// The source brings its region along: its cards follow the pointer with it, and their arrows and the shape follow them
		@objc func sourcePanned(_ recognizer: NSPanGestureRecognizer) {
			guard let cell = recognizer.view as? CanvasSourceCell else { return }
			let id = cell.model.source.id

			if isReadOnly {
				panCanvas(with: recognizer)
				return
			}

			switch recognizer.state {
				case .began:
					let members = regions.first { $0.source == id }?.members ?? []
					draggedSource = (id, cell.center, members.compactMap { member in cells[member].map { (member, $0.center) } })
					bringToFront(cell)
					cell.isLifted = true
					gridPoint = CanvasGrid.snapped(CanvasPoint(cell.center))
					updateHandles()
					NSCursor.closedHand.set()
					sourceDragStarted(id)

				case .changed:
					guard let draggedSource, draggedSource.id == id else { return }
					let travel = recognizer.translation(in: content)
					moveHeldSource(draggedSource, by: travel, animated: false)
					for member in draggedSource.members {
						updateArrows(touching: member.id, animation: nil)
					}
					updateRegion(of: id, animation: nil)
					gridPoint = CanvasGrid.snapped(CanvasPoint(cell.center))

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
					NSAnimationContext.animate(.spring(duration: 0.25, bounce: 0)) {
						moveHeldSource(held, by: settled, animated: true)
					}
					for member in held.members {
						updateArrows(touching: member.id, animation: 0.25)
					}
					updateRegion(of: id, animation: 0.25)
					updateHandles()
					updateCursor(at: recognizer.location(in: self))
					if finished {
						sourceMoved(id, target)
					}

				default:
					break
			}
		}

		func moveHeldSource(
			_ held: (id: BoardSource.ID, origin: CGPoint, members: [(id: Statement.ID, origin: CGPoint)]),
			by travel: CGPoint,
			animated: Bool
		) {
			sourceCells[held.id]?.setCenter(CGPoint(x: held.origin.x + travel.x, y: held.origin.y + travel.y), animated: animated)
			for member in held.members {
				cells[member.id]?.setCenter(CGPoint(x: member.origin.x + travel.x, y: member.origin.y + travel.y), animated: animated)
			}
		}

		/// A drag that moves the canvas rather than what it started on, in this view's points
		func panCanvas(with recognizer: NSPanGestureRecognizer) {
			switch recognizer.state {
				case .began, .changed:
					let travel = recognizer.translation(in: self)
					recognizer.setTranslation(.zero, in: self)
					pan(by: CGSize(width: travel.x, height: travel.y))
				default:
					updateHandles()
			}
		}

		// MARK: - Order

		/// Puts a box or source over the others without taking it out of `content`. Removing and adding it back, the usual
		/// way to reorder AppKit views, would take it out of the window for a moment and cancel a drag that's just started on it.
		func bringToFront(_ view: NSView) {
			guard content.subviews.last !== view else { return }
			var ranks: [ObjectIdentifier: Int] = [:]
			for (index, subview) in content.subviews.enumerated() {
				ranks[ObjectIdentifier(subview)] = index
			}
			ranks[ObjectIdentifier(view)] = Int.max
			let order = CanvasSubviewOrder(ranks: ranks)
			withExtendedLifetime(order) {
				unsafe content.sortSubviews(canvasSubviewOrder, context: Unmanaged.passUnretained(order).toOpaque())
			}
		}

		// MARK: - Gestures working together

		/// One thing moves at a time: the canvas, a box, a source, or an arrow being drawn
		func gestureRecognizerShouldBegin(_: NSGestureRecognizer) -> Bool {
			draggedBox == nil && draggedSource == nil && connection == nil && backgroundPress?.isPanning != true
		}

		/// A press on a box goes to its SwiftUI, so the canvas wouldn't otherwise become first responder and hear the keys
		func gestureRecognizer(_: NSGestureRecognizer, shouldAttemptToRecognizeWith _: NSEvent) -> Bool {
			if unsafe window?.firstResponder !== self {
				unsafe window?.makeFirstResponder(self)
			}
			return true
		}
	}

	/// Where each view goes in `bringToFront`'s sort, by identity
	final nonisolated class CanvasSubviewOrder: Sendable {
		let ranks: [ObjectIdentifier: Int]

		init(ranks: [ObjectIdentifier: Int]) {
			self.ranks = ranks
		}
	}

	/// `sortSubviews` takes a C function, so this can't capture anything: the ranks come through `context`
	private nonisolated func canvasSubviewOrder(_ first: NSView, _ second: NSView, _ context: UnsafeMutableRawPointer?) -> ComparisonResult {
		guard let context = unsafe context else { return .orderedSame }
		let ranks = unsafe Unmanaged<CanvasSubviewOrder>.fromOpaque(context).takeUnretainedValue().ranks
		let a = ranks[ObjectIdentifier(first)] ?? 0
		let b = ranks[ObjectIdentifier(second)] ?? 0
		return a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
	}
#endif
