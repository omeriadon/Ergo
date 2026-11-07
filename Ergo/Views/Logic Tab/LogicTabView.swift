//
//  LogicTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

/// The Logic tab: every saved scratchpad, newest first, and the editor each one opens.
struct LogicTabView: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(ScratchpadStore.self)
	private var scratchpadStore

	@Default(.logicLetters) var logicLetters

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	var body: some View {
		List {
			ForEach(scratchpadStore.sortedScratchpads) { scratchpad in
				Button {
					open(scratchpad.id)
				} label: {
					ScratchpadRow(scratchpad: scratchpad, letters: letters)
				}
				.buttonStyle(.plain)
				.swipeActions {
					Button("Delete", systemImage: "trash", role: .destructive) {
						scratchpadStore.delete([scratchpad.id])
					}
				}
			}
			.toolbarTitleVire("Logic", "function")
		}
		.overlay {
			if scratchpadStore.scratchpads.isEmpty {
				ContentUnavailableView(
					"No Scratchpads",
					systemImage: "function",
					description: Text("Anything you write on the Logic tab is kept here.")
				)
			}
		}
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("New Scratchpad", systemImage: "square.and.pencil") {
					scratchpadStore.newScratchpad()
					navigation.logicPath = [.scratchpad]
				}
				.accessibilityIdentifier("logic.newScratchpad")
			}
		}
		.onAppear {
			// Back from the editor, where an emptied scratchpad shouldn't stay in the list
			if navigation.logicPath.isEmpty {
				scratchpadStore.discardCurrentIfEmpty()
			}
		}
	}

	private func open(_ id: LogicScratchpad.ID) {
		scratchpadStore.open(id)
		navigation.logicPath = [.scratchpad]
	}
}

private struct ScratchpadRow: View {
	let scratchpad: LogicScratchpad
	let letters: [String]

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text(scratchpad.title(letters: letters))
					.font(.headline)
					.lineLimit(1)

				Text(scratchpad.modified, format: .relative(presentation: .named))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.contentShape(Rectangle())
	}
}
