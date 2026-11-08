//
//  CanvasArrow.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import UIKit

/// One arrow: the line, and a wide soft stroke under it for when it's selected
final class CanvasArrow {
	private let line = CAShapeLayer()
	private let glow = CAShapeLayer()

	init(in parent: CALayer) {
		for layer in [glow, line] {
			layer.fillColor = nil
			layer.lineCap = .round
			layer.lineJoin = .round
			parent.addSublayer(layer)
		}
		glow.lineWidth = 12
	}

	var path: CGPath? {
		line.path
	}

	func removeFromSuperlayer() {
		line.removeFromSuperlayer()
		glow.removeFromSuperlayer()
	}

	/// Slides to the new path over about `animation` seconds, or jumps to it without one
	func setPath(_ path: CGPath, animation: TimeInterval?) {
		for layer in [glow, line] {
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

	func style(isSelected: Bool, accent: UIColor, plain: UIColor) {
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		line.strokeColor = (isSelected ? accent : plain).cgColor
		line.lineWidth = isSelected ? 3.5 : 2.5
		glow.strokeColor = accent.withAlphaComponent(0.28).cgColor
		glow.isHidden = !isSelected
		CATransaction.commit()
	}
}
