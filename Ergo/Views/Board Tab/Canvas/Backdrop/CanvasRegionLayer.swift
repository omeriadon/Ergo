//
//  CanvasRegionLayer.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoLogic
#if os(iOS)
	import UIKit
#else
	import AppKit
#endif

/// One region on the canvas: a tinted fill, diagonal hatching cut to its shape, and an edge with a soft glow around it.
/// All vector layers, so it stays sharp at any zoom, and it doesn't take touches, so panning works across it.
final class CanvasRegionLayer {
	#if os(iOS)
		typealias PlatformColor = UIColor
	#else
		typealias PlatformColor = NSColor
	#endif

	/// Canvas units between the hatching's lines
	private static let hatchSpacing = 16.0

	private let fill = CAShapeLayer()
	private let hatch = CAShapeLayer()
	private let hatchMask = CAShapeLayer()
	private let glow = CAShapeLayer()
	private let edge = CAShapeLayer()

	init(in parent: CALayer) {
		for layer in [fill, hatch, glow, edge] {
			layer.lineJoin = .round
			layer.lineCap = .round
			parent.addSublayer(layer)
		}
		hatch.fillColor = nil
		hatch.lineWidth = 1.5
		hatch.mask = hatchMask
		glow.fillColor = nil
		glow.lineWidth = 10
		edge.fillColor = nil
		edge.lineWidth = 2
	}

	func removeFromSuperlayer() {
		for layer in [fill, hatch, glow, edge] {
			layer.removeFromSuperlayer()
		}
	}

	/// Slides to the new shape over about `animation` seconds, or jumps to it without one. The hatching stays still, in canvas
	/// space, and only its mask moves, so the lines don't swim as the shape changes.
	func setOutline(_ outline: [CanvasPoint], animation: TimeInterval?) {
		let path = Self.smoothPath(through: outline)

		CATransaction.begin()
		CATransaction.setDisableActions(true)
		hatch.path = Self.hatchLines(covering: path.boundingBoxOfPath)
		CATransaction.commit()

		for layer in [fill, hatchMask, glow, edge] {
			// Every outline has as many points as the last, so this always slides
			if let animation, let old = layer.path, old != path {
				let slide = CASpringAnimation(perceptualDuration: animation, bounce: 0)
				slide.keyPath = "path"
				slide.fromValue = old
				slide.toValue = path
				slide.duration = slide.settlingDuration
				layer.add(slide, forKey: "path")
			}
			CATransaction.begin()
			CATransaction.setDisableActions(true)
			layer.path = path
			CATransaction.commit()
		}
	}

	func style(accent: PlatformColor) {
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		fill.fillColor = accent.withAlphaComponent(0.07).cgColor
		hatch.strokeColor = accent.withAlphaComponent(0.2).cgColor
		glow.strokeColor = accent.withAlphaComponent(0.12).cgColor
		edge.strokeColor = accent.withAlphaComponent(0.6).cgColor
		CATransaction.commit()
	}

	// MARK: - Paths

	/// A smooth curve through the outline: each point pulls on a curve running between the middles of the pieces either side
	private static func smoothPath(through outline: [CanvasPoint]) -> CGPath {
		let path = CGMutablePath()
		let count = outline.count
		guard count >= 3 else { return path }

		func middle(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
			CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
		}

		path.move(to: middle(outline[count - 1].point, outline[0].point))
		for index in 0 ..< count {
			let point = outline[index].point
			path.addQuadCurve(to: middle(point, outline[(index + 1) % count].point), control: point)
		}
		path.closeSubpath()
		return path
	}

	/// Lines at 45° on a grid fixed to the canvas, wherever the shape is
	private static func hatchLines(covering rect: CGRect) -> CGPath {
		let path = CGMutablePath()
		guard !rect.isNull, rect.width > 0, rect.height > 0 else { return path }

		var offset = ((rect.minX + rect.minY) / hatchSpacing).rounded(.down) * hatchSpacing
		while offset < rect.maxX + rect.maxY {
			path.move(to: CGPoint(x: offset - rect.minY, y: rect.minY))
			path.addLine(to: CGPoint(x: offset - rect.maxY, y: rect.maxY))
			offset += hatchSpacing
		}
		return path
	}
}
