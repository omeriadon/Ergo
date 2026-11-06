//
//  CanvasConnectHandle.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// The glass arrow on the selected box. Dragging it to another box joins the two, and tapping it swaps which way:
/// an arrow pointing away from the box makes the other box a conclusion of this one, one pointing at the box makes
/// the other box a premise of it. `CanvasBoardView` places it and handles the drag and tap, this only draws it.
struct CanvasConnectHandle: View {
	static let size = 44.0

	/// Which side of the box it sits on
	let pointsUp: Bool

	/// The selected box is the conclusion, so the arrow points at it
	let asConclusion: Bool

	var body: some View {
		Image(systemName: pointsUp != asConclusion ? "arrow.up" : "arrow.down")
			.contentTransition(.symbolEffect(.replace))
			.font(.body.weight(.semibold))
			.foregroundStyle(.tint)
			.frame(width: Self.size, height: Self.size)
			.glassEffect(.regular.interactive(), in: Circle())
			.accessibilityHidden(true)
	}
}
