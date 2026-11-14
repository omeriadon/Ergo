//
//  ContentView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import SwiftUI

struct ContentView: View {
	@Default(.firstRunFinished) private var firstRunFinished

	var body: some View {
		// The tabs and their sheets only exist after the first run, so a sheet asked for during it (a shared item, an
		// invite) waits and shows over the tabs when they appear
		if firstRunFinished {
			MainView()
				.transition(.opacity)
		} else {
			FirstRunView()
				.transition(.opacity)
		}
	}
}

private struct MainView: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		@Bindable var router = navigation

		// The tabs read the selected tab themselves, so changing tabs only changes which sheet this shows
		AppTabs()
			.sheet(item: $router.visibleSheet) { sheet in
				switch sheet {
					case let .app(sheet):
						AppSheetContent(sheet: sheet)

					case let .board(sheet):
						BoardSheetContent(sheet: sheet)

					case let .logic(sheet):
						LogicSheetContent(sheet: sheet)

					case let .library(sheet):
						LibrarySheetContent(sheet: sheet)
				}
			}
			.fontDesign(.rounded)
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

/// The tab bar and its tabs. Selecting a tab only changes this view, not `ContentView`.
private struct AppTabs: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(CatalogStore.self) private var catalog

	/// SwiftUI only calls the setter for the user's own taps; intents change `NavigationManager` directly. That keeps intent-driven navigation out of the donations.
	private var tabSelection: Binding<AppTab> {
		Binding(
			get: {
				navigation.selectedTab
			},
			set: { newValue in
				guard newValue != navigation.selectedTab else {
					return
				}

				navigation.selectedTab = newValue
				IntentDonations.tab(newValue)
			}
		)
	}

	/// Same idea as `tabSelection`. Only pushes are donated, not pops or the same path written back.
	private var libraryPath: Binding<[LibraryRoute]> {
		Binding(
			get: {
				navigation.libraryPath
			},
			set: { newValue in
				let previous = navigation.libraryPath
				navigation.libraryPath = newValue

				if newValue.count > previous.count, let route = newValue.last {
					IntentDonations.route(route, catalog: catalog)
				}
			}
		)
	}

	private var logicPath: Binding<[LogicRoute]> {
		Binding(
			get: {
				navigation.logicPath
			},
			set: { newValue in
				navigation.logicPath = newValue
			}
		)
	}

	var body: some View {
		TabView(selection: tabSelection) {
			Tab(value: .board) {
				NavigationStack {
					BoardTabView()
				}
			} label: {
				Label("Board", systemImage: "flowchart")
					.labelStyle(.iconOnly)
			}

			Tab(value: .logic) {
				NavigationStack(path: logicPath) {
					LogicTabView()
						.navigationDestination(for: LogicRoute.self) { route in
							switch route {
								case .scratchpad:
									ScratchpadEditorView()

								case .course:
									LogicCourseView()

								case let .lesson(id):
									LogicLessonView(lessonID: id)
							}
						}
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
				NavigationStack(path: libraryPath) {
					LibraryTabView()
						.navigationDestination(for: LibraryRoute.self) { route in
							switch route {
								case let .category(category):
									LibraryCategoryView(category: category)

								case let .detail(category, id):
									LibraryDetailView(category: category, id: id)

								case let .symbols(filter):
									LibraryListView<LogicSymbol>(initialFilter: filter.libraryFilter)

								case let .biases(filter):
									LibraryListView<Bias>(initialFilter: filter.libraryFilter)

								case let .razors(filter):
									LibraryListView<Razor>(initialFilter: filter.libraryFilter)

								case let .paradoxes(filter):
									LibraryListView<Paradox>(initialFilter: filter.libraryFilter)

								case let .concepts(filter):
									LibraryListView<Concept>(initialFilter: filter.libraryFilter)

								case let .fallacies(filter):
									LibraryListView<Fallacy>(initialFilter: filter.libraryFilter)

								case let .arguments(filter):
									LibraryListView<Argument>(initialFilter: filter.libraryFilter)

								case .bookmarks:
									BookmarksView()
							}
						}
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
