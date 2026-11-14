//
//  ContentView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct ContentView: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(\.horizontalSizeClass)
	private var horizontalSizeClass

	var body: some View {
		// Chosen by width alone, so a window that's resized switches layout. Both draw the same `NavigationManager` and
		// stores, so nothing is lost when it does.
		let isWide = horizontalSizeClass == .regular

		// The tabs read the selected tab themselves, so changing tabs only changes which sheet this shows
		layout(isWide: isWide)
			.sheet(item: navigation.visibleSheetBinding(isWide: isWide)) { sheet in
				switch sheet {
					case let .app(sheet):
						AppSheetContent(sheet: sheet)

					case let .board(sheet):
						BoardSheetContent(sheet: sheet)

					case let .logic(sheet):
						LogicSheetContent(sheet: sheet)

					case let .library(sheet):
						LibrarySheetContent(sheet: sheet)

					case .onboarding:
						OnboardingSheet()
				}
			}
			.fontDesign(.rounded)
	}

	@ViewBuilder
	private func layout(isWide: Bool) -> some View {
		if isWide {
			WideLayout()
		} else {
			AppTabs()
		}
	}
}

private struct AppSheetContent: View {
	let sheet: AppSheet

	var body: some View {
		switch sheet {
			case .scanner:
				Text("sheet here!")

			case .paste:
				Text("sheet here!")

			case .result:
				Text("sheet here!")

			case .settings:
				SettingsView()

			case let .shared(item):
				SharedItemSheet(item: item)

			case let .joinBoard(token):
				JoinBoardSheet(token: token)

			case let .addToChat(content):
				AddToChatSheet(content: content)

			case .plus:
				PlusSheet()
		}
	}
}

/// The tab bar and its tabs, for narrow windows. Selecting a tab only changes this view, not `ContentView`.
private struct AppTabs: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(CatalogStore.self) private var catalog

	var body: some View {
		@Bindable var router = navigation

		TabView(selection: navigation.donatingTabSelection) {
			Tab(value: .board) {
				NavigationStack {
					BoardTabView()
				}
			} label: {
				Label("Board", systemImage: "flowchart")
					.labelStyle(.iconOnly)
			}

			Tab(value: .logic) {
				NavigationStack(path: $router.logicPath) {
					LogicTabView()
						.logicDestinations()
				}
			} label: {
				Label("Logic", systemImage: "function")
					.labelStyle(.iconOnly)
			}

			Tab(value: .ask) {
				NavigationStack {
					AskTabView()
				}
			} label: {
				Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
					.labelStyle(.iconOnly)
			}

			Tab(value: .library, role: .prominent) {
				NavigationStack(path: navigation.donatingLibraryPath(catalog: catalog)) {
					LibraryTabView()
						.libraryDestinations()
						.toolbarTitleItem()
				}
			} label: {
				Label("Library", systemImage: "books.vertical")
					.labelStyle(.iconOnly)
			}
		}
		.tabViewStyle(.tabBarOnly)
		.tabBarMinimizeBehavior(.onScrollDown)
		.modifier(DeepResearchAccessory())
		.tabBarHaptics()
		.tabTransition {
			if navigation.selectedTab == .board {
				navigation.presentSheet(.boards)
			}
		}
	}
}

#Preview {
	@Previewable @State var thing = NavigationManager()
	@Previewable @State var catalog = CatalogStore()
	@Previewable @State var boardStore = BoardStore()
	@Previewable @State var scratchpadStore = ScratchpadStore()
	@Previewable @State var askStore = AskStore()
	@Previewable @State var analysisStore = BoardAnalysisStore()
	@Previewable @State var account = TranslationAccount()

	ContentView()
		.environment(thing)
		.environment(catalog)
		.environment(boardStore)
		.environment(scratchpadStore)
		.environment(askStore)
		.environment(analysisStore)
		.environment(account)
		.onAppear {
			thing.startup()
			thing.selectedTab = .board
			thing.libraryPath = [.bookmarks, .category(.philosophers), .detail(category: .philosophers, id: "david-hume")]
			Task {
				try? await catalog.load()
			}
		}
}
