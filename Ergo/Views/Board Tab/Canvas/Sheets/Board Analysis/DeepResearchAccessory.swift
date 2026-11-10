//
//  DeepResearchAccessory.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import SwiftUI

/// The bar above the tabs while a board's deep research runs. Tapping it opens that board's analysis.
struct DeepResearchAccessory: ViewModifier {
	private struct Run {
		var board: Board.ID
		var title: String
	}

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardAnalysisStore.self)
	private var analysis

	@Environment(BoardStore.self)
	private var boardStore

	/// A run that's gone quiet stops counting with nothing changing, so this moves on while one is showing
	@State private var now = Date.now

	private var runs: [Run] {
		analysis.running(at: now).compactMap { id in
			boardStore.boards.first { $0.id == id }.map { Run(board: id, title: $0.title) }
		}
	}

	func body(content: Content) -> some View {
		let runs = runs
		// The board on screen first, since that's the one it would be about
		let shown = runs.first { $0.board == boardStore.currentID } ?? runs.first

		content
			.tabViewBottomAccessory(isEnabled: shown != nil) {
				if let shown {
					DeepResearchAccessoryButton(title: shown.title, others: runs.count - 1) {
						navigation.openAnalysis(of: shown.board, in: boardStore)
					}
				}
			}
			.task(id: runs.isEmpty) {
				guard !runs.isEmpty else { return }
				while !Task.isCancelled {
					now = .now
					try? await Task.sleep(for: .seconds(60))
				}
			}
	}
}

private struct DeepResearchAccessoryButton: View {
	let title: String
	let others: Int
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 10) {
				ProgressView()

				Text("Researching \(title)")
					.lineLimit(1)

				Spacer(minLength: 0)

				if others > 0 {
					Text("+\(others)")
						.foregroundStyle(.secondary)
				}
			}
			.padding(.horizontal)
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
		.accessibilityIdentifier("deepResearch.accessory")
	}
}
