//
//  CanvasConnectHandle.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// One of the glass arrows above and below the selected box, pointing the way it's dragged. Dragging the one above to
/// another box makes this box a conclusion of that one, and dragging the one below makes this box a premise of it.
/// `CanvasBoardView` places it and handles the drag, this only draws it.
struct CanvasConnectHandle: View {
	static let size = 44.0

	/// Whether it's the one above the box
	let pointsUp: Bool

	var body: some View {
		Image(systemName: pointsUp ? "arrow.up" : "arrow.down")
			.font(.body.weight(.semibold))
			.foregroundStyle(.tint)
			.frame(width: Self.size, height: Self.size)
			.glassEffect(.regular.interactive(), in: Circle())
			.accessibilityHidden(true)
	}
}
