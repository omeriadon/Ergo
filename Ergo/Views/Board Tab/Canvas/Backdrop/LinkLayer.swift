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
	private static let headLength = 16.0
	private static let headSpread = 0.5

	let segment: CanvasSegment
	let control: CanvasPoint

	/// Nil when the boxes overlap so far that there is no line left to draw
	init?(from source: CanvasPoint, to target: CanvasPoint) {
		guard let segment = CanvasGeometry.arrow(from: .box(at: source), to: .box(at: target)) else { return nil }
		self.segment = segment
		control = CanvasGeometry.controlPoint(for: segment)
	}

	/// From a box to a point that isn't on a box, for the arrow following a finger
	init(from source: CanvasPoint, toward end: CanvasPoint) {
		segment = CanvasSegment(start: CanvasGeometry.exit(of: .box(at: source), toward: end), end: end)
		control = CanvasGeometry.controlPoint(for: segment)
	}

	/// From a point that isn't on a box to a box, for the arrow following a finger the other way round
	init(from start: CanvasPoint, into target: CanvasPoint) {
		segment = CanvasSegment(start: start, end: CanvasGeometry.exit(of: .box(at: target), toward: start))
		control = CanvasGeometry.controlPoint(for: segment)
	}

	/// Halfway along the curve
	var middle: CGPoint {
		CanvasGeometry.point(on: segment, control: control, at: 0.5).point
	}

	func distance(from point: CanvasPoint) -> Double {
		CanvasGeometry.distance(from: point, toCurve: segment, control: control)
	}

	/// The curve with its head, two short strokes back from the tip along the curve's last direction
	var path: Path {
		var path = Path()
		path.move(to: segment.start.point)
		path.addQuadCurve(to: segment.end.point, control: control.point)

		let end = segment.end
		let heading = atan2(end.y - control.y, end.x - control.x)
		for turn in [Self.headSpread, -Self.headSpread] {
			let angle = heading + .pi + turn
			path.move(to: CGPoint(x: end.x + cos(angle) * Self.headLength, y: end.y + sin(angle) * Self.headLength))
			path.addLine(to: end.point)
		}
		return path
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
