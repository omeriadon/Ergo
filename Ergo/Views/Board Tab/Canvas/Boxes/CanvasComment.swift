//
//  CanvasComment.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ErgoLogic
import ErgoProtocol
import SwiftUI

/// Where a box's comment hangs, in the box's own coordinates. Below it and off to the right, so it mostly stays clear of
/// arrows leaving the middle of the box. A fixed size, since nothing on the canvas is laid out from a measured one.
nonisolated enum CanvasCommentLayout {
	static let size = CGSize(width: 170, height: 62)
	static let origin = CGPoint(x: CanvasLayout.boxSize.width / 2 + 14, y: CanvasLayout.boxSize.height + 6)

	static var frame: CGRect {
		CGRect(origin: origin, size: size)
	}
}

/// A finding beside what it's about. It draws outside its box, and `CanvasBoxCell` takes the taps, since SwiftUI can't
/// receive them out there.
struct CanvasCommentOverlay: View {
	let comment: BoardAnalysisComment?

	var body: some View {
		if let comment {
			VStack(alignment: .leading, spacing: 2) {
				Text(comment.title)
					.font(.caption2.weight(.bold))
					.lineLimit(1)
				Text(comment.text)
					.font(.caption2)
					.lineLimit(3)
			}
			.foregroundStyle(.primary)
			.padding(.horizontal, 8)
			.padding(.vertical, 5)
			.frame(width: CanvasCommentLayout.size.width, height: CanvasCommentLayout.size.height, alignment: .topLeading)
			.background(Color.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
			.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
			.overlay {
				RoundedRectangle(cornerRadius: 10)
					.strokeBorder(.yellow.opacity(0.6), lineWidth: 1)
			}
			.offset(x: CanvasCommentLayout.origin.x, y: CanvasCommentLayout.origin.y)
			.allowsHitTesting(false)
		}
	}
}
