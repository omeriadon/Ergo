//
//  CanvasBoardView+Connecting.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

#if os(iOS)
	import ErgoLogic
	import SwiftUI
	import UIKit

	extension CanvasBoardView {
		// MARK: - Connecting

		/// Shows the handles on the selected box. Dragging the one above makes the box a conclusion of what it's dragged to,
		/// and dragging the one below makes it a premise. Let go on empty canvas, that other box is made there.
		func updateHandles() {
			guard !isReadOnly, let id = selectedStatement, cells[id] != nil, draggedBox == nil, connection == nil else {
				for handle in handles where handle.alpha > 0 {
					UIView.animate(withDuration: 0.12) {
						handle.alpha = 0
					}
				}
				return
			}

			if handles.isEmpty {
				handles = [makeHandle(isAbove: true), makeHandle(isAbove: false)]
			}

			if handles.allSatisfy({ $0.alpha == 0 }) {
				UIView.performWithoutAnimation {
					positionHandles()
				}
			} else {
				positionHandles()
			}
			UIView.animate(withDuration: 0.12) {
				for handle in handles {
					handle.alpha = 1
				}
			}
		}

		func positionHandles() {
			guard let id = selectedStatement, let box = cells[id] else { return }
			let center = canvasTransform.screen(CanvasPoint(box.center))
			let reach = CanvasLayout.boxSize.height / 2 * canvasTransform.scale + 8 + CanvasConnectHandle.size / 2
			for handle in handles {
				handle.center = CGPoint(x: center.x, y: center.y + (handle.isAbove ? -reach : reach))
			}
		}

		func makeHandle(isAbove: Bool) -> CanvasHandleView {
			let handle = CanvasHandleView(isAbove: isAbove, content: handleContent)
			handle.alpha = 0

			let drag = UIPanGestureRecognizer(target: self, action: #selector(handlePanned))
			drag.maximumNumberOfTouches = 1
			drag.delegate = self
			handle.addGestureRecognizer(drag)

			addSubview(handle)
			return handle
		}

		@objc func handlePanned(_ recognizer: UIPanGestureRecognizer) {
			switch recognizer.state {
				case .began:
					guard let source = selectedStatement, let handle = recognizer.view as? CanvasHandleView else { return }
					let arrow = CanvasArrow(in: arrowLayer)
					connection = (source, nil, arrow, handle.isAbove)
					styleArrows()
					haptics.prepare()
					updateHandles()
					connectStarted(source, handle.isAbove)
					followConnection(to: recognizer.location(in: content))

				case .changed:
					followConnection(to: recognizer.location(in: content))

				case .ended, .cancelled, .failed:
					guard let finished = connection else { return }
					let drop = recognizer.state == .ended ? connectionDrop(of: finished.source, over: finished.target, at: recognizer.location(in: self)) : .nowhere
					connection = nil
					gridPoint = nil
					dropLens.setShown(false)
					finished.arrow.removeFromSuperlayer()
					updateHandles()
					connectEnded(finished.source, drop)

				default:
					break
			}
		}

		func connectionDrop(of source: Statement.ID, over target: Statement.ID?, at location: CGPoint) -> ConnectionDrop {
			if let target {
				return .box(target)
			}
			let point = canvasTransform.canvas(location)
			let isOnSource = cells[source].map { CanvasRect.box(at: CanvasPoint($0.center)).contains(point) } ?? true
			let isOnHandle = handles.contains { $0.frame.contains(location) }
			return isOnSource || isOnHandle ? .nowhere : .space(point)
		}

		func wouldMakeBox(from source: Statement.ID, over target: Statement.ID?, at location: CGPoint) -> Bool {
			guard cells.count < ArgumentMapValidator.defaultMaximumStatements,
			      case .space = connectionDrop(of: source, over: target, at: location)
			else {
				return false
			}
			return true
		}

		/// The arrow reaches for the box under the finger, and follows the finger when there isn't one
		func followConnection(to point: CGPoint) {
			guard let current = connection, let source = cells[current.source]?.center else { return }

			let target = content.subviews.reversed()
				.compactMap { $0 as? CanvasBoxCell }
				.first { $0.model.statement.id != current.source && $0.frame.contains(point) }
			let targetID = target?.model.statement.id
			if targetID != current.target {
				connection?.target = targetID
				connectTargetChanged(targetID)
				if targetID != nil {
					haptics.reachedBox()
				}
			}
			if target == nil {
				feelGrid(at: point)
			} else {
				gridPoint = nil
			}

			let location = convert(point, from: content)
			dropLens.center = location
			dropLens.setShown(wouldMakeBox(from: current.source, over: targetID, at: location))

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
