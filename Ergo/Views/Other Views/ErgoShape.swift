//
//  ErgoShape.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct ErgoShape: Shape {
	func path(in rect: CGRect) -> Path {
		var path = Path()

		// Original SVG dimensions: 92 × 92
		let scale = min(rect.width, rect.height) / 92

		let offsetX = rect.midX - 46 * scale
		let offsetY = rect.midY - 46 * scale

		let circles: [(x: CGFloat, y: CGFloat)] = [
			(46, 26.5039),
			(26.2344, 63.7891),
			(65.8555, 63.7891),
		]

		let radius: CGFloat = 9.8828

		for circle in circles {
			path.addEllipse(in: CGRect(
				x: offsetX + (circle.x - radius) * scale,
				y: offsetY + (circle.y - radius) * scale,
				width: radius * 2 * scale,
				height: radius * 2 * scale
			))
		}

		return path
	}
}
