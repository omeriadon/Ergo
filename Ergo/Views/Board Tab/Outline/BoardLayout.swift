//
//  BoardLayout.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import Defaults
import SwiftUI

/// How the Board tab draws a board. Remembered on this device (`Defaults.Keys.boardLayout`).
nonisolated enum BoardLayout: String, Hashable, Codable, Defaults.Serializable {
	/// Cards where they were put, with arrows between them
	case canvas

	/// Each argument as an indented list, which suits a keyboard
	case outline
}

/// Switches the board between the canvas and the outline, in the board's toolbar
struct BoardLayoutButton: View {
	@Default(.boardLayout)
	private var layout

	var body: some View {
		switch layout {
			case .canvas:
				Button("Show as Outline", systemImage: "list.bullet.indent") {
					layout = .outline
				}
				.accessibilityIdentifier("board.showOutline")
			case .outline:
				Button("Show as Canvas", systemImage: "rectangle.connected.to.line.below") {
					layout = .canvas
				}
				.accessibilityIdentifier("board.showCanvas")
		}
	}
}
