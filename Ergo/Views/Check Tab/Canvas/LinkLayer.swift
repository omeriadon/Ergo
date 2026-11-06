//
//  LinkLayer.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// The curve an arrow takes between two boxes, from `CanvasGeometry`
struct ArrowCurve {
	let segment: CanvasSegment
	let control: CanvasPoint

	/// Nil when the boxes overlap so far that there is no line left to draw
	init?(from source: CanvasPoint, to target: CanvasPoint) {
		guard let segment = CanvasGeometry.arrow(from: .box(at: source), to: .box(at: target)) else { return nil }
		self.segment = segment
		control = CanvasGeometry.controlPoint(for: segment)
	}

	func distance(from point: CanvasPoint) -> Double {
		CanvasGeometry.distance(from: point, toCurve: segment, control: control)
	}
}

/// One arrow. Both ends are animatable, so Arrange slides the arrows along with the boxes.
struct LinkShape: Shape {
	private static let headLength = 16.0
	private static let headSpread = 0.5

	var source: CanvasPoint
	var target: CanvasPoint

	var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
		get {
			AnimatablePair(AnimatablePair(source.x, source.y), AnimatablePair(target.x, target.y))
		}
		set {
			source = CanvasPoint(x: newValue.first.first, y: newValue.first.second)
			target = CanvasPoint(x: newValue.second.first, y: newValue.second.second)
		}
	}

	func path(in _: CGRect) -> Path {
		guard let curve = ArrowCurve(from: source, to: target) else { return Path() }

		var path = Path()
		path.move(to: curve.segment.start.point)
		path.addQuadCurve(to: curve.segment.end.point, control: curve.control.point)

		// The head is two short strokes back from the tip along the curve's last direction
		let end = curve.segment.end
		let heading = atan2(end.y - curve.control.y, end.x - curve.control.x)
		for turn in [Self.headSpread, -Self.headSpread] {
			let angle = heading + .pi + turn
			path.move(to: CGPoint(x: end.x + cos(angle) * Self.headLength, y: end.y + sin(angle) * Self.headLength))
			path.addLine(to: end.point)
		}
		return path
	}
}

/// Every arrow in one layer behind the boxes. They aren't accessibility elements: each box says what it connects to.
struct LinkLayer: View {
	let links: [Link]

	/// Where each box is right now, including one that is being dragged
	let positions: [Statement.ID: CanvasPoint]

	let selected: Link.ID?

	var body: some View {
		ZStack {
			ForEach(links) { link in
				if let source = positions[link.premise], let target = positions[link.conclusion] {
					arrow(link, from: source, to: target)
				}
			}
		}
		.allowsHitTesting(false)
		.accessibilityHidden(true)
	}

	private func arrow(_ link: Link, from source: CanvasPoint, to target: CanvasPoint) -> some View {
		let isSelected = link.id == selected
		return ZStack {
			if isSelected {
				// A wide soft stroke under the line, so the selected arrow reads from further away
				LinkShape(source: source, target: target)
					.stroke(Color.accentColor.opacity(0.28), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
			}
			LinkShape(source: source, target: target)
				.stroke(
					isSelected ? Color.accentColor : Color.secondary,
					style: StrokeStyle(lineWidth: isSelected ? 3.5 : 2.5, lineCap: .round, lineJoin: .round)
				)
		}
	}
}

// MARK: - Tapping

enum LinkHitTest {
	/// The arrow nearest to `point`, if any is within `tolerance` canvas units
	static func link(
		near point: CanvasPoint,
		tolerance: Double,
		in links: [Link],
		positions: [Statement.ID: CanvasPoint]
	) -> Link.ID? {
		var nearest: (id: Link.ID, distance: Double)?
		for link in links {
			guard let source = positions[link.premise], let target = positions[link.conclusion],
			      let curve = ArrowCurve(from: source, to: target)
			else { continue }

			let distance = curve.distance(from: point)
			if distance <= tolerance, distance < (nearest?.distance ?? .infinity) {
				nearest = (link.id, distance)
			}
		}
		return nearest?.id
	}
}
