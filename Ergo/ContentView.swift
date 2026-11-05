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

	var body: some View {
		@Bindable var router = navigation

		TabView(selection: $router.selectedTab) {
			Tab(value: .check) {
				NavigationStack {
					CheckTabView()
						.toolbarTitleItem()
				}
			} label: {
				Label("Check", systemImage: "checkmark.seal")
			}

			Tab(value: .debate) {
				NavigationStack {
					HStack {
						Text("debate")
						Image("Ergo")
					}
					.toolbarTitleItem()
				}
			} label: {
				Label("Debate", systemImage: "bubble.left.and.text.bubble.right")
			}

			Tab(value: .library, role: .prominent) {
				NavigationStack(path: $router.libraryPath) {
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
		.sheet(item: $router.presentedSheet) { sheet in
			switch sheet {
				case .scanner:
					Text("sheet here!")

				case .paste:
					Text("sheet here!")

				case .result:
					Text("sheet here!")

				case .createDebate:
					Text("sheet here!")

				case .settings:
					SettingsView()

				case .about:
					AboutView()

				case .logicLetters:
					LogicLettersSheet()

				case .pages:
					PagesSheet()
			}
		}
		.fontDesign(.rounded)
	}
}

#Preview {
	@Previewable @State var thing = NavigationManager()
	@Previewable @State var catalog = CatalogStore()

	ContentView()
		.environment(thing)
		.environment(catalog)
		.onAppear {
			thing.startup()
			thing.selectedTab = .check
			thing.libraryPath = [.bookmarks, .category(.philosophers), .detail(category: .philosophers, id: "david-hume")]
			Task {
				try? await catalog.load()
			}
		}
}
