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
		@Bindable var router = navigation

		TabView(selection: tabSelection) {
			Tab(value: .board) {
				NavigationStack {
					BoardTabView()
						.toolbarTitleItem()
				}
			} label: {
				Label("Board", systemImage: "flowchart")
			}

			Tab(value: .logic) {
				NavigationStack(path: logicPath) {
					LogicTabView()
						.toolbarTitleItem()
						.navigationDestination(for: LogicRoute.self) { route in
							switch route {
								case .scratchpad:
									ScratchpadEditorView()
							}
						}
				}
			} label: {
				Label("Logic", systemImage: "function")
			}

			Tab(value: .ask) {
				NavigationStack {
					AskTabView()
						.toolbarTitleItem()
				}
			} label: {
				Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
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
			}
		}
		.tabViewStyle(.tabBarOnly)
		.tabBarMinimizeBehavior(.onScrollDown)
		.sheet(item: $router.presentedSheet) { sheet in
			switch sheet {
				case .scanner:
					Text("sheet here!")

				case .paste:
					Text("sheet here!")

				case .result:
					Text("sheet here!")

				case .settings:
					SettingsView()

				case .logicLetters:
					LogicLettersSheet()

				case .boards:
					BoardsSheet()
			}
		}
		.fontDesign(.rounded)
	}
}

#Preview {
	@Previewable @State var thing = NavigationManager()
	@Previewable @State var catalog = CatalogStore()
	@Previewable @State var boardStore = BoardStore()
	@Previewable @State var scratchpadStore = ScratchpadStore()
	@Previewable @State var account = TranslationAccount()

	ContentView()
		.environment(thing)
		.environment(catalog)
		.environment(boardStore)
		.environment(scratchpadStore)
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
