//
//  WideLayout.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import SwiftUI

/// The layout for wide windows: the sections and their items in a sidebar, the open item beside it, and the board's
/// panels in an inspector. It draws the same `NavigationManager` and stores the tabs do, so a window that's resized
/// between the two keeps everything.
struct WideLayout: View {
	@Environment(BoardStore.self)
	private var boardStore

	/// The board's undo steps, kept here because the detail drops the board when another section is chosen. Cleared
	/// when the board changes, even while it's off screen.
	@State private var history = CanvasHistory()

	var body: some View {
		NavigationSplitView {
			WideSidebar()
		} detail: {
			WideDetail()
		}
		.environment(\.canvasHistory, history)
		.onChange(of: boardStore.current.id) {
			history.clear()
		}
	}
}

/// The open item in the selected section
private struct WideDetail: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		switch navigation.selectedTab {
			case .board:
				WideBoardDetail()

			case .logic:
				WideLogicDetail()

			case .ask:
				WideAskDetail()

			case .library:
				WideLibraryDetail()
		}
	}
}

// MARK: - Board

/// The current board, with the panel that's open beside it in the inspector
private struct WideBoardDetail: View {
	@Environment(NavigationManager.self)
	private var navigation

	/// Closing the inspector closes the panel. A panel that's already gone (or moved to a sheet) is left alone.
	private var isPanelShown: Binding<Bool> {
		Binding(
			get: {
				navigation.boardPanel != nil
			},
			set: { newValue in
				if !newValue, navigation.boardPanel != nil {
					navigation.boardSheet = nil
				}
			}
		)
	}

	var body: some View {
		NavigationStack {
			BoardTabView()
		}
		.inspector(isPresented: isPanelShown) {
			WideBoardPanel()
		}
	}
}

private struct WideBoardPanel: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		Group {
			if let panel = navigation.boardPanel {
				BoardSheetContent(sheet: panel)
			}
		}
		.inspectorColumnWidth(min: 320, ideal: 380, max: 520)
	}
}

// MARK: - Logic

/// The scratchpads are listed in the sidebar, so the stack starts empty and the editor is pushed onto it
private struct WideLogicDetail: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		@Bindable var router = navigation

		NavigationStack(path: $router.logicPath) {
			WideLogicEmpty()
				.logicDestinations()
		}
	}
}

private struct WideLogicEmpty: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(ScratchpadStore.self)
	private var scratchpadStore

	var body: some View {
		ContentUnavailableView {
			Label("No Scratchpad Open", systemImage: "function")
		} description: {
			Text("Choose a scratchpad in the sidebar, or start a new one.")
		} actions: {
			Button("New Scratchpad", systemImage: "square.and.pencil") {
				scratchpadStore.newScratchpad()
				navigation.logicPath = [.scratchpad]
			}
			.buttonStyle(.glassProminent)
			.accessibilityIdentifier("logic.newScratchpad")
		}
		.onAppear {
			// Back from the editor, where an emptied scratchpad shouldn't stay in the list
			if navigation.logicPath.isEmpty {
				scratchpadStore.discardCurrentIfEmpty()
			}
		}
	}
}

// MARK: - Ask

/// The chats are listed in the sidebar, so this is just the open one
private struct WideAskDetail: View {
	@Environment(AskStore.self)
	private var store

	@Environment(TranslationAccount.self)
	private var account

	var body: some View {
		NavigationStack {
			if !account.isSignedInHere {
				// Signed out, the tab is only its sign-in prompt
				AskTabView()
			} else if store.isChatOpen {
				AskThreadView()
			} else {
				WideAskEmpty()
			}
		}
	}
}

private struct WideAskEmpty: View {
	var body: some View {
		ContentUnavailableView(
			"No Chat Open",
			systemImage: "bubble.left.and.text.bubble.right",
			description: Text("Choose a chat in the sidebar, or start a new one.")
		)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				AskNewChatButton()
					.buttonStyle(.glassProminent)
			}
		}
	}
}

// MARK: - Library

private struct WideLibraryDetail: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(CatalogStore.self)
	private var catalog

	var body: some View {
		NavigationStack(path: navigation.donatingLibraryPath(catalog: catalog)) {
			LibraryTabView()
				.libraryDestinations()
		}
	}
}
