//
//  LibraryListView.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// LibraryListView.swift

import Defaults
import SwiftUI

struct LibraryListView<Item: LibraryListItem>: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self) private var navigation

	private let initialFilter: LibraryFilter?

	@State private var appliedInitialFilter = false

	@State private var searchPresented = false

	@State private var searchedItems: [Item] = []

	init(initialFilter: LibraryFilter? = nil) {
		self.initialFilter = initialFilter
	}

	private var state: LibraryListState {
		navigation.listState(for: Item.category)
	}

	private var trimmedSearch: String {
		state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var isSearching: Bool {
		searchPresented && !trimmedSearch.isEmpty
	}

	private var allItems: [Item] {
		Item.all(in: catalog)
	}

	private var visibleItems: [Item] {
		LibraryListLogic.visibleItems(
			all: allItems,
			searched: searchedItems,
			isSearching: isSearching,
			filters: state.filters
		)
	}

	private var suggestions: [LibraryFilter] {
		LibraryListLogic.suggestions(
			available: Item.availableFilters,
			selected: state.filters,
			term: state.searchText
		)
	}

	private var searchTaskID: String {
		"\(searchPresented)-\(trimmedSearch)-\(catalog.isLoaded)"
	}

	var body: some View {
		List {
			suggestionsSection
			resultsSections
			footer
		}
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: visibleItems.map(\.id)
		)
		.animation(.easeInOut(duration: 0.2), value: searchPresented)
		.animation(.easeInOut(duration: 0.2), value: state.filters)
		.listSectionIndexVisibility(Item.showsSectionIndex ? .visible : .hidden)
		.scrollEdgeEffectStyle(.soft, for: .all)
		.toolbarMinimizationBehavior(.never, for: .navigationBar)
		.searchable(
			text: Bindable(state).searchText,
			tokens: Bindable(state).filters,
			isPresented: $searchPresented,
			placement: .navigationBarDrawer(displayMode: .always),
			prompt: Item.searchPrompt
		) { filter in
			Text(filter.title)
		}
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.onSubmit(of: .search) {
			IntentDonations.search(state.searchText)
		}
		.navigationTitle(Item.listTitle)
		.toolbar {
			ToolbarItem(placement: .title) {
				Text(Item.listTitle)
			}

			if !Item.availableFilters.isEmpty {
				ToolbarItem(placement: .topBarTrailing) {
					LibraryFilterMenu<Item>(state: state, donate: donateFilters)
						.background(state.filters.isEmpty ? .clear : .accent, in: Circle())
				}
			}
		}
		.onAppear(perform: applyInitialFilter)
		.onChange(of: state.searchText, initial: true) { _, newValue in
			if !newValue.isEmpty {
				searchPresented = true
			}
		}
		.task(id: searchTaskID, performSearch)
	}

	@ViewBuilder
	private var suggestionsSection: some View {
		if searchPresented, !suggestions.isEmpty {
			LibraryFilterSuggestions<Item>(suggestions: suggestions, state: state, donate: donateFilters)
		}
	}

	@ViewBuilder
	private var resultsSections: some View {
		if visibleItems.isEmpty, catalog.isLoaded {
			ContentUnavailableView.search(text: state.searchText)
		} else if isSearching {
			Section {
				ForEach(visibleItems) { item in
					LibraryListRow(item: item)
						.transition(.opacity)
				}
			}
		} else {
			ForEach(LibraryListLogic.sections(visibleItems)) { section in
				Section(section.title) {
					ForEach(section.items) { item in
						LibraryListRow(item: item)
							.transition(.opacity)
					}
				}
				.sectionIndexLabel(section.title)
			}
		}
	}

	@ViewBuilder
	private var footer: some View {
		if !searchPresented {
			Text("\(allItems.count) \(Item.countLabel)")
				.font(.caption)
				.foregroundStyle(.secondary)
				.listRowBackground(Color.clear)
		}
	}

	/// Donates the list as it looks after the user changed its filters.
	private func donateFilters() {
		IntentDonations.libraryList(Item.category, filters: state.filters)
	}

	private func applyInitialFilter() {
		guard !appliedInitialFilter else {
			return
		}

		appliedInitialFilter = true

		if let initialFilter {
			state.filters = [initialFilter]
		}
	}

	@Sendable
	private func performSearch() async {
		guard searchPresented, !trimmedSearch.isEmpty, catalog.isLoaded else {
			searchedItems = []
			return
		}

		do {
			try await Task.sleep(for: .milliseconds(120))

			let matches = try await Item.ranked(allItems, query: trimmedSearch)

			try Task.checkCancellation()

			searchedItems = matches
		} catch is CancellationError {
			return
		} catch {
			searchedItems = []
		}
	}
}
