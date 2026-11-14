//
//  AppCommands.swift
//  Ergo
//

import SwiftUI

/// What the open board offers the menu bar, published by `CanvasView` while it's in the focused window
struct CanvasCommandActions {
	let isReadOnly: Bool
	let isAnalysing: Bool
	let find: () -> Void
	let fit: () -> Void
	let arrange: () -> Void
	let quickAI: () -> Void
	let deepResearch: () -> Void
}

extension FocusedValues {
	@Entry var canvasCommands: CanvasCommandActions?
}

/// The menu bar (and an iPad's keyboard shortcuts): new items in File, Settings in the app menu, and a Board menu for the
/// open board. Each goes through `NavigationManager` and the stores, the way the sidebar does.
struct AppCommands: Commands {
	let navigation: NavigationManager
	let boardStore: BoardStore
	let scratchpadStore: ScratchpadStore

	@FocusedValue(\.canvasCommands)
	private var canvas

	var body: some Commands {
		// One window's worth of state, so ⌘N makes a board rather than a second window
		CommandGroup(replacing: .newItem) {
			Button("New Board") {
				navigation.newBoard(in: boardStore)
			}
			.keyboardShortcut("n")

			Button("New Scratchpad") {
				navigation.newScratchpad(in: scratchpadStore)
			}
			.keyboardShortcut("n", modifiers: [.command, .shift])
		}

		CommandGroup(replacing: .appSettings) {
			Button("Settings…") {
				navigation.presentSheet(.settings(id: "3refd"))
			}
			.keyboardShortcut(",")
		}

		CommandMenu("Board") {
			Button("Find…") {
				canvas?.find()
			}
			.keyboardShortcut("f")
			.disabled(canvas == nil)

			Button("Fit to Window") {
				canvas?.fit()
			}
			.keyboardShortcut("0", modifiers: [.command, .option])
			.disabled(canvas == nil)

			Button("Arrange") {
				canvas?.arrange()
			}
			.disabled(canvas?.isReadOnly ?? true)

			Divider()

			Button("Quick AI") {
				canvas?.quickAI()
			}
			.disabled(canvas == nil)

			Button("Deep Research") {
				canvas?.deepResearch()
			}
			.disabled(canvas.map { $0.isReadOnly || $0.isAnalysing } ?? true)
		}
	}
}
