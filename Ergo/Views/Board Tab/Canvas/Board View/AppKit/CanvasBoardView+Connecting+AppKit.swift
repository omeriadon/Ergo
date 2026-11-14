//
//  CanvasBoardView+Connecting+AppKit.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

#if os(macOS)
	import AppKit
	import ErgoLogic
	import SwiftUI

	extension CanvasBoardView {
		// MARK: - Connecting

		/// The box that gets the handles: the one under the pointer, or else the selected one. None while something is being
		/// dragged, while picking the other end of an arrow, or on a board that can only be viewed.
		var handleTarget: Statement.ID? {
			guard !isReadOnly, !isPicking, draggedBox == nil, draggedSource == nil, connection == nil else { return nil }
			if let hoveredStatement, cells[hoveredStatement] != nil {
				return hoveredStatement
			}
			if let selectedStatement, cells[selectedStatement] != nil {
				return selectedStatement
			}
			return nil
		}

		/// Shows the handles on `handleTarget`. Dragging the one above makes the box a conclusion of what it's dragged to,
		/// and dragging the one below makes it a premise. Let go on empty canvas, that other box is made there.
		/// `slides` is for inside an animation of the whole canvas, so the handles move with it.
		func updateHandles(slides: Bool = false) {
			guard let id = handleTarget else {
				handleOwner = nil
				for handle in handles where handle.alphaValue > 0 {
					NSAnimationContext.animate(.easeOut(duration: 0.12)) {
						handle.animator().alphaValue = 0
					}
				}
				return
			}

			if handles.isEmpty {
				handles = [makeHandle(isAbove: true), makeHandle(isAbove: false)]
			}

			// Handles coming out appear in place, rather than sliding from wherever they last were
			let wereHidden = handles.allSatisfy { $0.alphaValue == 0 }
			handleOwner = id
			positionHandles(animated: slides && !wereHidden)
			for handle in handles where handle.alphaValue < 1 {
				NSAnimationContext.animate(.easeOut(duration: 0.12)) {
					handle.animator().alphaValue = 1
				}
			}
		}

		/// Handles live in this view rather than the canvas, so they stay the same size at any zoom
		func positionHandles(animated: Bool = false) {
			guard let id = handleOwner, let box = cells[id] else { return }
			let center = canvasTransform.screen(CanvasPoint(box.center))
			let reach = CanvasLayout.boxSize.height / 2 * canvasTransform.scale + 8 + CanvasConnectHandle.size / 2
			for handle in handles {
				handle.setCenter(CGPoint(x: center.x, y: center.y + (handle.isAbove ? -reach : reach)), animated: animated)
			}
		}

		func makeHandle(isAbove: Bool) -> CanvasHandleView {
			let handle = CanvasHandleView(isAbove: isAbove, content: handleContent)
			handle.alphaValue = 0
			handle.addGestureRecognizer(makeDrag(#selector(handlePanned)))
			addSubview(handle)
			return handle
		}

		@objc func handlePanned(_ recognizer: NSPanGestureRecognizer) {
			switch recognizer.state {
				case .began:
					guard !isReadOnly, let source = handleOwner, let handle = recognizer.view as? CanvasHandleView else { return }
					let arrow = CanvasArrow(in: arrowLayer)
					connection = (source, nil, arrow, handle.isAbove)
					styleArrows()
					updateHandles()
					NSCursor.crosshair.set()
					connectStarted(source, handle.isAbove)
					followConnection(to: recognizer.location(in: content))

				case .changed:
					followConnection(to: recognizer.location(in: content))

				case .ended, .cancelled, .failed:
					guard let finished = connection else { return }
					let drop = recognizer.state == .ended ? connectionDrop(of: finished.source, over: finished.target, at: recognizer.location(in: self)) : .nowhere
					connection = nil
					gridPoint = nil
					finished.arrow.removeFromSuperlayer()
					updateHandles()
					updateCursor(at: recognizer.location(in: self))
					connectEnded(finished.source, drop)

				default:
					break
			}
		}

		/// `location` is in this view's points
		func connectionDrop(of source: Statement.ID, over target: Statement.ID?, at location: CGPoint) -> ConnectionDrop {
			if let target {
				return .box(target)
			}
			let point = canvasTransform.canvas(location)
			let isOnSource = cells[source].map { CanvasRect.box(at: CanvasPoint($0.center)).contains(point) } ?? true
			let isOnHandle = handles.contains { $0.frame.contains(location) }
			return isOnSource || isOnHandle ? .nowhere : .space(point)
		}

		/// The arrow reaches for the box under the pointer, and follows the pointer when there isn't one. `point` is on the canvas.
		func followConnection(to point: CGPoint) {
			guard let current = connection, let source = cells[current.source]?.center else { return }

			let target = content.subviews.reversed()
				.compactMap { $0 as? CanvasBoxCell }
				.first { $0.model.statement.id != current.source && $0.frame.contains(point) }
			let targetID = target?.model.statement.id
			if targetID != current.target {
				connection?.target = targetID
				connectTargetChanged(targetID)
			}
			gridPoint = target == nil ? CanvasGrid.snapped(CanvasPoint(point)) : nil

			let curve: ArrowCurve? = if let target {
				current.asConclusion
					? ArrowCurve(from: CanvasPoint(target.center), to: CanvasPoint(source))
					: ArrowCurve(from: CanvasPoint(source), to: CanvasPoint(target.center))
			} else if CanvasRect.box(at: CanvasPoint(source)).contains(CanvasPoint(point)) {
				nil
			} else if current.asConclusion {
				ArrowCurve(from: CanvasPoint(point), into: CanvasPoint(source))
			} else {
				ArrowCurve(from: CanvasPoint(source), toward: CanvasPoint(point))
			}
			current.arrow.setPath(curve?.path.cgPath ?? CGMutablePath(), animation: nil)
		}
	}
#endif
