//
//  NavigationDestinations.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import SwiftUI

// The pages the Logic and Library stacks push, and the bindings that drive those stacks. The tabs and the wide layout
// both use them, so the two layouts push the same pages from the same state.

extension View {
	/// What `LogicRoute`s open
	func logicDestinations() -> some View {
		navigationDestination(for: LogicRoute.self) { route in
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

	/// What `LibraryRoute`s open
	func libraryDestinations() -> some View {
		navigationDestination(for: LibraryRoute.self) { route in
			LibraryDestination(route: route)
		}
	}
}

private struct LibraryDestination: View {
	let route: LibraryRoute

	var body: some View {
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

			case .practice:
				PracticeView()
		}
	}
}

extension NavigationManager {
	/// SwiftUI only calls the setter for the user's own taps; intents change `NavigationManager` directly. That keeps
	/// intent-driven navigation out of the donations.
	var donatingTabSelection: Binding<AppTab> {
		Binding(
			get: {
				self.selectedTab
			},
			set: { newValue in
				guard newValue != self.selectedTab else {
					return
				}

				self.selectedTab = newValue
				IntentDonations.tab(newValue)
			}
		)
	}

	/// Same idea as `donatingTabSelection`. Only pushes are donated, not pops or the same path written back.
	func donatingLibraryPath(catalog: CatalogStore) -> Binding<[LibraryRoute]> {
		Binding(
			get: {
				self.libraryPath
			},
			set: { newValue in
				let previous = self.libraryPath
				self.libraryPath = newValue

				if newValue.count > previous.count, let route = newValue.last {
					IntentDonations.route(route, catalog: catalog)
				}
			}
		)
	}
}
