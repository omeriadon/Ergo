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

	@Default(.bookmarks) private var bookmarks

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

	private var searchBinding: Binding<String> {
		Binding(
			get: {
				state.searchText
			},
			set: { newValue in
				state.searchText = newValue
			}
		)
	}

	private var filtersBinding: Binding<[LibraryFilter]> {
		Binding(
			get: {
				state.filters
			},
			set: { newValue in
				state.filters = newValue
			}
		)
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
			text: searchBinding,
			tokens: filtersBinding,
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
					filterMenu
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
			Section("Filters") {
				ForEach(suggestions) { filter in
					Button {
						state.toggle(filter)
						state.searchText = ""
						donateFilters()
					} label: {
						Label(filter.title, systemImage: filter.kind.tokenImage)
					}
					.accessibilityIdentifier("library.\(Item.category.rawValue).filter.\(filter.key)")
				}
			}
		}
	}

	@ViewBuilder
	private var resultsSections: some View {
		if visibleItems.isEmpty, catalog.isLoaded {
			ContentUnavailableView.search(text: state.searchText)
		} else if isSearching {
			Section {
				ForEach(visibleItems) { item in
					itemRow(item)
				}
			}
		} else {
			ForEach(LibraryListLogic.sections(visibleItems)) { section in
				Section(section.title) {
					ForEach(section.items) { item in
						itemRow(item)
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

	private func itemRow(_ item: Item) -> some View {
		let target = CatalogReference(
			id: item.id,
			name: item.name,
			category: Item.category
		)

		let isBookmarked = bookmarks.contains(target)

		return NavigationLink(
			value: LibraryRoute.detail(
				category: Item.category,
				id: item.id
			)
		) {
			HStack {
				item.row

				Spacer()

				if isBookmarked {
					Image(systemName: "bookmark")
						.foregroundStyle(.secondary)
						.symbolVariant(.fill)
				}
			}
			.accessibilityIdentifier("library.\(Item.category.rawValue).\(item.id)")
			.contextMenu {
				Button {
					toggleBookmark(target, isBookmarked: isBookmarked)
				} label: {
					if isBookmarked {
						Label("Remove Bookmark", systemImage: "bookmark.fill")
					} else {
						Label("Bookmark", systemImage: "bookmark")
					}
				}
			} preview: {
				LibraryDetailView(category: target.category, id: target.id)
					.environment(catalog)
					.environment(navigation)
			}
		}
		.buttonStyle(.plain)
		.swipeActions(edge: .trailing) {
			Button {
				toggleBookmark(target, isBookmarked: isBookmarked)
			} label: {
				Label(
					isBookmarked ? "Remove Bookmark" : "Bookmark",
					systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
				)
			}
			.buttonStyle(.automatic)
			.tint(.accentColor)
		}
		.listedEntity(Item.Entity.self, id: item.id)
		.transition(.opacity)
	}

	private var filterMenu: some View {
		let kinds = Set(Item.availableFilters.map(\.kind)).sorted()

		return Menu {
			if kinds.count > 1 {
				ForEach(kinds, id: \.self) { kind in
					Menu(kind.title, systemImage: kind.systemImage) {
						filterToggles(of: kind)
					}
					.menuActionDismissBehavior(.disabled)
				}
			} else if let kind = kinds.first {
				filterToggles(of: kind)
			}

			Divider()

			Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle") {
				withAnimation(.easeInOut(duration: 0.2)) {
					state.clearFilters()
				}
				IntentDonations.clearFilters()
			}
			.disabled(state.filters.isEmpty)
			.accessibilityIdentifier("library.\(Item.category.rawValue).clearFilters")
		} label: {
			Label("Filters", systemImage: "line.3.horizontal.decrease")
				.labelStyle(.iconOnly)
		}
		.accessibilityIdentifier("library.\(Item.category.rawValue).filters")
		.menuActionDismissBehavior(.disabled)
	}

	private func filterToggles(of kind: LibraryFilter.Kind) -> some View {
		ForEach(Item.availableFilters.filter { $0.kind == kind }) { filter in
			Toggle(
				filter.title,
				isOn: Binding(
					get: {
						state.filters.contains(filter)
					},
					set: { _ in
						withAnimation(.easeInOut(duration: 0.2)) {
							state.toggle(filter)
						}
						donateFilters()
					}
				)
			)
		}
	}

	/// Donates the list as it looks after the user changed its filters.
	private func donateFilters() {
		IntentDonations.libraryList(Item.category, filters: state.filters)
	}

	private func toggleBookmark(
		_ target: CatalogReference,
		isBookmarked: Bool
	) {
		IntentDonations.bookmark(target, added: !isBookmarked, catalog: catalog)

		withAnimation(.easeInOut) {
			if isBookmarked {
				bookmarks.remove(target)
			} else {
				bookmarks.insert(target)
			}
		}
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
