//
//  CanvasSurface.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// Pan and zoom for the canvas. Everything inside `content` is laid out in canvas units and moved by one
/// transform, so boxes and arrows stay together.
///
/// A one finger drag on the background pans, a pinch zooms about where the fingers started. Both are drawn live
/// from gesture state and only written to `transform` when they end. A flick keeps the canvas gliding after the
/// finger lifts, slowing down the way a scroll view does, until a touch or something else moves it.
struct CanvasSurface<Content: View>: View {
	/// Pinching this far past the largest zoom means "go into the box", not "zoom more"
	private static var openFactor: CGFloat {
		1.25
	}

	private struct Pinch: Equatable {
		var magnification: CGFloat
		var anchor: CGPoint
	}

	@Binding var transform: CanvasTransform

	/// A tap that landed on nothing, in this view's coordinates
	let tapBackground: (CGPoint) -> Void

	/// The pinch was still going after the zoom ran out, starting at this point
	let pinchedPastLimit: (CGPoint) -> Void

	@ViewBuilder let content: Content

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@GestureState private var pan = CGSize.zero
	@GestureState private var pinch: Pinch?
	@State private var hasOpened = false

	/// The glide after a flick, nil when the canvas is still
	@State private var inertia: Task<Void, Never>?

	/// How far the glide has moved the canvas so far. It lives here, not in `transform`, so a glide redraws only
	/// this view: writing the shared transform each frame would rebuild the whole canvas and its toolbar 120 times a second.
	@State private var gliding = CGSize.zero

	private var live: CanvasTransform {
		var result = transform
		if let pinch {
			result = transform.zoomed(to: transform.scale * pinch.magnification, about: pinch.anchor)
		}
		result.offset.width += pan.width + gliding.width
		result.offset.height += pan.height + gliding.height
		return result
	}

	var body: some View {
		Color.clear
			.contentShape(Rectangle())
			.onTapGesture(coordinateSpace: .local, perform: tapBackground)
			.gesture(panGesture)
			.accessibilityHidden(true)
			// An overlay is given this view's size and has no say in it, so nothing on the canvas can change the
			// size of the surface. Boxes are placed from its top left corner, and may sit far outside it.
			.overlay(alignment: .topLeading) {
				content
					.scaleEffect(live.scale, anchor: .topLeading)
					.offset(live.offset)
			}
			.coordinateSpace(.named(CanvasCoordinateSpace.name))
			.simultaneousGesture(magnifyGesture)
			.onChange(of: pinch == nil) { _, ended in
				if ended {
					hasOpened = false
				}
			}
			.onDisappear(perform: stopInertia)
			.accessibilityIdentifier("check.canvas")
	}

	// MARK: - Gestures

	private var panGesture: some Gesture {
		DragGesture(minimumDistance: 6)
			.updating($pan) { value, state, _ in
				state = value.translation
			}
			.onChanged { _ in
				stopInertia()
			}
			.onEnded { value in
				transform.offset.width += value.translation.width
				transform.offset.height += value.translation.height
				glide(velocity: value.velocity)
			}
	}

	private var magnifyGesture: some Gesture {
		MagnifyGesture()
			.updating($pinch) { value, state, _ in
				state = Pinch(magnification: value.magnification, anchor: value.startLocation)
			}
			.onChanged { value in
				stopInertia()
				let wanted = transform.scale * value.magnification
				if !hasOpened, wanted >= CanvasTransform.zoomRange.upperBound * Self.openFactor {
					hasOpened = true
					pinchedPastLimit(value.startLocation)
				}
			}
			.onEnded { value in
				transform = transform.zoomed(to: transform.scale * value.magnification, about: value.startLocation)
			}
	}

	// MARK: - Inertia

	/// Keeps the canvas moving at `velocity` (points per second), slowing down until it stops. It is time based,
	/// so a late frame moves the canvas further instead of making the glide slower.
	private func glide(velocity: CGSize) {
		stopInertia()

		let speed = hypot(velocity.width, velocity.height)
		guard !reduceMotion, speed > Glide.smallestFlick else { return }

		let scale = min(speed, Glide.fastestFlick) / speed
		var current = CGSize(width: velocity.width * scale, height: velocity.height * scale)

		inertia = Task { @MainActor in
			let clock = ContinuousClock()
			var last = clock.now
			let start = transform.offset

			while !Task.isCancelled {
				try? await Task.sleep(for: .milliseconds(8))
				guard !Task.isCancelled else { return }

				// Something else moved the canvas (Fit, a new page), so the glide is no longer wanted
				guard transform.offset == start else {
					gliding = .zero
					inertia = nil
					return
				}

				let now = clock.now
				let elapsed = last.duration(to: now)
				last = now
				let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) * 1e-18

				let slowing = exp(-Glide.friction * seconds)
				let distance = (1 - slowing) / Glide.friction
				gliding.width += current.width * distance
				gliding.height += current.height * distance

				current.width *= slowing
				current.height *= slowing
				if hypot(current.width, current.height) < Glide.stillSpeed {
					break
				}
			}

			finishGlide()
		}
	}

	/// Hands what the glide has moved over to the shared transform
	private func finishGlide() {
		transform.offset.width += gliding.width
		transform.offset.height += gliding.height
		gliding = .zero
		inertia = nil
	}

	/// A touch, or the view going away, ends the glide where it is
	private func stopInertia() {
		guard inertia != nil else { return }
		inertia?.cancel()
		finishGlide()
	}
}

/// How a flick of the canvas glides to a stop
private enum Glide {
	/// Slower than this, a lift of the finger is a stop rather than a flick
	static let smallestFlick: CGFloat = 120

	/// A hard flick doesn't send the canvas further than a quick one would
	static let fastestFlick: CGFloat = 3500

	/// How quickly the glide slows: the speed falls by this fraction of itself each second, which is close to
	/// the deceleration of a scroll view
	static let friction = 2.4

	/// The glide has finished once it is slower than this, in points per second
	static let stillSpeed: CGFloat = 8
}
