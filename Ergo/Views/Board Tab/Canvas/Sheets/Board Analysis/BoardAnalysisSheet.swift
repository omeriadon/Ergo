//
//  BoardAnalysisSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoProtocol
import ErgoSync
import SwiftUI

/// What the server's analysis found on a board: the status of the run, its discussion, and everything it annotated.
/// With a `focus`, only what's about that one thing.
struct BoardAnalysisSheet: View {
	let board: Board.ID
	let focus: BoardAnalysisTarget?

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(SyncController.self)
	private var sync

	@Environment(AskStore.self)
	private var askStore

	private var current: Board? {
		boardStore.boards.first { $0.id == board }
	}

	var body: some View {
		NavigationStack {
			content
				.environment(\.openURL, OpenURLAction { url in
					// A library link is one of the app's intents, as in Ask. Anything else goes wherever a link goes.
					guard let intent = AskIntent(url: url) else {
						return .systemAction
					}
					AskIntents.run(intent, navigation: navigation, store: askStore)
					return .handled
				})
				.toolbarTitleVire("Analysis", "text.magnifyingglass")
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						Button(role: .close) {
							navigation.dismissSheet()
						}
						.accessibilityIdentifier("analysis.close")
					}
				}
		}
		// Deleted on another device, or this sheet was restored after that happened
		.onChange(of: current == nil, initial: true) {
			if current == nil {
				navigation.dismissSheet()
			}
		}
	}

	@ViewBuilder
	private var content: some View {
		if !sync.isSignedIn {
			AnalysisNeedsAccountView()
		} else if let current {
			AnalysisContent(board: current, focus: focus)
		}
	}
}

// MARK: - Signed out

struct AnalysisNeedsAccountView: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		ContentUnavailableView {
			Label("Analysis Needs an Account", systemImage: "person.crop.circle.badge.plus")
		} description: {
			Text("Sign in under Account in Settings, so the analysis has somewhere to run and its findings somewhere to arrive.")
		} actions: {
			Button("Open Settings", systemImage: "gearshape") {
				navigation.presentSheet(.settings(id: "3refd"))
			}
			.buttonStyle(.glass)
			.accessibilityIdentifier("analysis.openSettings")
		}
	}
}

// MARK: - Content

struct AnalysisContent: View {
	let board: Board
	let focus: BoardAnalysisTarget?

	@Environment(BoardAnalysisStore.self)
	private var analysis

	var body: some View {
		let shown = analysis.shown(on: board)
		let outline = AnalysisOutline(board: board, current: shown.current, focus: focus)

		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				if focus == nil {
					AnalysisStatusView(board: board, hasStale: shown.hasStale)
					AnalysisDiscussionView(board: board.id)
				}

				if outline.isEmpty {
					AnalysisEmptyView(board: board.id, hasStale: shown.hasStale)
				}

				ForEach(outline.groups) { group in
					AnalysisGroupView(group: group)
				}

				Text("Whether the premises are true wasn't assessed.")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier("analysis.footer")
			}
			.padding()
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}
