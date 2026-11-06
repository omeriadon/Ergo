//
//  CanvasTransform.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

extension CanvasPoint {
	init(_ point: CGPoint) {
		self.init(x: point.x, y: point.y)
	}

	var point: CGPoint {
		CGPoint(x: x, y: y)
	}
}

/// Where the canvas sits on screen. A point on the canvas lands at `canvas * scale + offset`.
/// Pan and zoom both change this one value, so nothing else needs to know about either.
struct CanvasTransform: Equatable {
	static let zoomRange: ClosedRange<CGFloat> = 0.3 ... 1.6

	var offset = CGSize.zero
	var scale: CGFloat = 1

	func screen(_ point: CanvasPoint) -> CGPoint {
		CGPoint(x: point.x * scale + offset.width, y: point.y * scale + offset.height)
	}

	func canvas(_ point: CGPoint) -> CanvasPoint {
		CanvasPoint(x: (point.x - offset.width) / scale, y: (point.y - offset.height) / scale)
	}

	/// Zooms to `newScale` and keeps whatever is under `anchor` (a screen point) where it is
	func zoomed(to newScale: CGFloat, about anchor: CGPoint) -> CanvasTransform {
		let clamped = min(max(newScale, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
		let ratio = clamped / scale
		return CanvasTransform(
			offset: CGSize(
				width: anchor.x - (anchor.x - offset.width) * ratio,
				height: anchor.y - (anchor.y - offset.height) * ratio
			),
			scale: clamped
		)
	}

	// MARK: - Fit

	/// The transform that shows all of `rects` centred in the part of `size` the bars leave free.
	/// A board that is small stays at a readable size instead of being blown up to fill the screen.
	static func fitting(_ rects: [CanvasRect], in size: CGSize, insets: EdgeInsets, margin: CGFloat = 28) -> CanvasTransform {
		guard let first = rects.first, size.width > 0, size.height > 0 else { return CanvasTransform() }

		var minX = first.minX, maxX = first.maxX, minY = first.minY, maxY = first.maxY
		for rect in rects.dropFirst() {
			minX = min(minX, rect.minX)
			maxX = max(maxX, rect.maxX)
			minY = min(minY, rect.minY)
			maxY = max(maxY, rect.maxY)
		}

		let free = CGRect(
			x: insets.leading + margin,
			y: insets.top + margin,
			width: max(size.width - insets.leading - insets.trailing - 2 * margin, 1),
			height: max(size.height - insets.top - insets.bottom - 2 * margin, 1)
		)
		let width = max(maxX - minX, 1)
		let height = max(maxY - minY, 1)
		let scale = min(free.width / width, free.height / height, 1.25)
		let clamped = min(max(scale, zoomRange.lowerBound), zoomRange.upperBound)

		return CanvasTransform(
			offset: CGSize(
				width: free.midX - (minX + width / 2) * clamped,
				height: free.midY - (minY + height / 2) * clamped
			),
			scale: clamped
		)
	}
}

// MARK: - Boxes

extension CanvasRect {
	/// The box a statement is drawn as, with its centre at `center`
	static func box(at center: CanvasPoint) -> CanvasRect {
		CanvasRect(center: center, size: CanvasLayout.boxSize)
	}
}
