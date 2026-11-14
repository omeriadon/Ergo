//
//  CanvasBoardView+Gestures.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

#if os(iOS)
	import ErgoLogic
	import SwiftUI
	import UIKit

	extension CanvasBoardView {
		// MARK: - Pan and zoom

		@objc func touchedDown(_ recognizer: UILongPressGestureRecognizer) {
			if recognizer.state == .began {
				touchStoppedGlide = glideLink != nil
				stopGlide()
			}
		}

		@objc func tapped(_ recognizer: UITapGestureRecognizer) {
			guard !touchStoppedGlide else { return }
			tapBackground(canvasTransform.canvas(recognizer.location(in: self)))
		}

		@objc func panned(_ recognizer: UIPanGestureRecognizer) {
			let travel = recognizer.translation(in: self)
			recognizer.setTranslation(.zero, in: self)

			switch recognizer.state {
				case .began, .changed:
					// A second finger makes this a pinch, which moves the canvas itself
					guard pinchRecognizer.state != .began, pinchRecognizer.state != .changed else { return }
					hasBeenMoved = true
					canvasTransform.offset.width += travel.x
					canvasTransform.offset.height += travel.y
					applyTransform()

				case .ended:
					glide(velocity: recognizer.velocity(in: self))
					updateHandles()

				case .cancelled, .failed:
					updateHandles()

				default:
					break
			}
		}

		/// Zooms about where the fingers started, and follows them if they move together
		@objc func pinched(_ recognizer: UIPinchGestureRecognizer) {
			switch recognizer.state {
				case .began:
					stopGlide()
					hasBeenMoved = true
					pinchStart = canvasTransform
					pinchAnchor = recognizer.location(in: self)

				case .changed:
					guard recognizer.numberOfTouches >= 2 else { return }
					let location = recognizer.location(in: self)
					var transform = pinchStart.zoomed(to: pinchStart.scale * recognizer.scale, about: pinchAnchor)
					transform.offset.width += location.x - pinchAnchor.x
					transform.offset.height += location.y - pinchAnchor.y
					canvasTransform = transform
					applyTransform()

				case .ended, .cancelled, .failed:
					updateHandles()

				default:
					break
			}
		}

		// MARK: - Inertia

		/// Keeps the canvas moving at `velocity` (points per second), slowing down the way a scroll view does
		func glide(velocity: CGSize) {
			stopGlide()

			let speed = hypot(velocity.width, velocity.height)
			guard unsafe !UIAccessibility.isReduceMotionEnabled, speed > Glide.smallestFlick else { return }

			let scale = min(speed, Glide.fastestFlick) / speed
			glideVelocity = CGSize(width: velocity.width * scale, height: velocity.height * scale)

			let link = CADisplayLink(target: self, selector: #selector(glideFrame))
			link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
			link.add(to: .main, forMode: .common)
			glideLink = link
		}

		func glide(velocity: CGPoint) {
			glide(velocity: CGSize(width: velocity.x, height: velocity.y))
		}

		@objc func glideFrame(_ link: CADisplayLink) {
			let seconds = link.targetTimestamp - (glideTime ?? link.timestamp)
			glideTime = link.targetTimestamp

			let slowing = exp(-Glide.friction * seconds)
			let distance = (1 - slowing) / Glide.friction
			canvasTransform.offset.width += glideVelocity.width * distance
			canvasTransform.offset.height += glideVelocity.height * distance
			applyTransform()

			glideVelocity.width *= slowing
			glideVelocity.height *= slowing
			if hypot(glideVelocity.width, glideVelocity.height) < Glide.stillSpeed {
				stopGlide()
			}
		}

		func stopGlide() {
			guard let link = glideLink else { return }
			link.invalidate()
			glideLink = nil
			glideTime = nil
			updateHandles()
		}

		// MARK: - Gestures working together

		var isCanvasMoving: Bool {
			if glideLink != nil {
				return true
			}
			return isRecognizing(panRecognizer) || isRecognizing(pinchRecognizer)
		}

		func isRecognizing(_ recognizer: UIGestureRecognizer) -> Bool {
			let state = recognizer.state
			return state == .began || state == .changed
		}

		/// Panning and tapping the canvas only count on its background. `hitTest` sends a touch here when it's on nothing,
		/// or when it stops a glide, in which case a drag that follows pans the canvas even over a box.
		func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
			// A box that can't be picked up shouldn't get in the way of panning
			if recognizer === panRecognizer, isReadOnly {
				return true
			}
			if recognizer === panRecognizer || recognizer === tapRecognizer {
				return touch.view === self
			}
			return true
		}

		/// One thing moves at a time: the canvas, a box, a source, or an arrow being drawn
		override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
			if recognizer === touchDownRecognizer {
				return true
			}
			if recognizer === panRecognizer || recognizer === pinchRecognizer || recognizer === tapRecognizer {
				return draggedBox == nil && draggedSource == nil && connection == nil
			}
			return !isReadOnly && !isCanvasMoving
		}

		func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
			if recognizer === touchDownRecognizer || other === touchDownRecognizer {
				return true
			}
			return (recognizer === panRecognizer && other === pinchRecognizer) || (recognizer === pinchRecognizer && other === panRecognizer)
		}
	}

	/// How a flick of the canvas glides to a stop
	private enum Glide {
		/// Slower than this, a lift of the finger is a stop rather than a flick
		static let smallestFlick: CGFloat = 120

		/// A hard flick doesn't send the canvas further than a quick one would
		static let fastestFlick: CGFloat = 5000

		/// How quickly the glide slows: the speed falls by this fraction of itself each second, which is close to
		/// the deceleration of a scroll view
		static let friction = 2.4

		/// The glide has finished once it is slower than this, in points per second
		static let stillSpeed: CGFloat = 8
	}
#endif
