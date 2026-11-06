//
//  CanvasConnectHandle.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// The glass arrow on the selected box. Dragging it to another box makes that box a conclusion of this one.
/// `CanvasBoardView` places it and handles the drag, this only draws it.
struct CanvasConnectHandle: View {
	static let size = 44.0

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
