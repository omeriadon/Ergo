//
//  CanvasArrow.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

#if os(iOS)
	import ErgoSync
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

		/// `strength` is what the analysis made of the arrow: conclusive and strong are solid, conclusive thicker, weak is
		/// dashed and none is dotted, each in `strengthColor`. Nil, with no analysis, is as it always was.
		func style(isSelected: Bool, accent: UIColor, plain: UIColor, strength: BoardArrowStrength? = nil, strengthColor: UIColor? = nil) {
			CATransaction.begin()
			CATransaction.setDisableActions(true)
			line.strokeColor = (isSelected ? accent : strengthColor ?? plain).cgColor
			line.lineWidth = (isSelected ? 3.5 : 2.5) + (strength == .conclusive ? 1.5 : 0)
			switch strength {
				case .weak?:
					line.lineDashPattern = [9, 6]
				case BoardArrowStrength.none?:
					line.lineDashPattern = [0.1, 7]
				default:
					line.lineDashPattern = nil
			}
			glow.strokeColor = accent.withAlphaComponent(0.28).cgColor
			glow.isHidden = !isSelected
			CATransaction.commit()
		}
	}
#endif
