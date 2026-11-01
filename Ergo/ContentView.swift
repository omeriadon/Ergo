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
						.toolbar {
							ToolbarTitleItem()
						}
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
					.toolbar {
						ToolbarTitleItem()
					}
				}
			} label: {
				Label("Debate", systemImage: "bubble.left.and.text.bubble.right")
			}

			Tab(value: .library) {
				NavigationStack(path: $router.libraryPath) {
					LibraryTabView()
						.navigationDestination(for: ItemRoute.self) { route in
							ItemDetailView(route: route, origin: .library)
						}
						.toolbar {
							ToolbarTitleItem()
						}
				}
			} label: {
				Label("Library", systemImage: "books.vertical")
			}

			Tab(value: .search, role: .prominent) {
				NavigationStack(path: $router.searchPath) {
					SearchTabView()
						.navigationDestination(for: ItemRoute.self) { route in
							ItemDetailView(route: route, origin: .search)
						}
						.toolbar {
							ToolbarTitleItem()
						}
				}
			} label: {
				Label("Search", systemImage: "magnifyingglass")
			}

		}
		.sheet(item: $router.presentedSheet) { sheet in
			switch sheet {
				case .scanner:
					Text("sheet here!")

				case .paste:
					Text("sheet here!")

				case .result(_):
					Text("sheet here!")

				case .createDebate:
					Text("sheet here!")

				case .invite(_):
					Text("sheet here!")

				case .export(_):
					Text("sheet here!")
			}
		}
    }
}

struct ToolbarTitleItem: ToolbarContent {
	var body: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			ToolbarTitleView()
		}
		.visibilityPriority(.high)
		.sharedBackgroundVisibility(.hidden)
	}
}

struct ToolbarTitleView: View {
	var body: some View {
		Image("Ergo")
			.foregroundStyle(.primary)
	}
}

#Preview {
    ContentView()
		.environment(NavigationManager())
}
