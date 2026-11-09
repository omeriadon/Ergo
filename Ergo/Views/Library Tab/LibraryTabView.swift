//
//  LibraryTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct LibraryTabView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(CatalogStore.self) private var catalog

	private var searchBinding: Binding<String> {
		Binding(
			get: {
				navigation.libraryGeneralSearchText
			},
			set: { newValue in
				navigation.libraryGeneralSearchText = newValue
			}
		)
	}

	private var searchTerm: String {
		navigation.libraryGeneralSearchText
	}

	@State private var searchPresented = false
	@State private var searchResults: [LibrarySearchEntry] = []

	private var libraryEntries: [LibrarySearchEntry] {
		let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return [] }
		return catalog.searchEntries
	}

	var scrollView: some View {
		let results = searchPresented ? searchResults : []

		return ScrollView {
			if searchPresented {
				if searchTerm.isEmpty {
					LibrarySearchPrompt()
						.padding(.top, 90)
						.listRowBackground(Color.clear)
						.frame(maxWidth: .infinity, alignment: .center)
						.transition(.opacity)
				} else if results.isEmpty, searchTerm.count > 2 {
					ContentUnavailableView.search(text: searchTerm)
						.tint(.accent)
						.padding(.top, 90)
						.transition(.opacity)
				} else {
					LazyVStack(alignment: .leading, spacing: 10) {
						resultsList
					}
					.padding(.horizontal, 7)
					.padding(.top, 20)
					.transition(.opacity)
				}
			} else {
				LibraryGridView()
					.padding()
					.transition(.opacity)
			}
		}
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: results.map(\.id)
		)
	}

	var resultsList: some View {
		let results = searchPresented ? searchResults : []

		return ForEach(results) { result in
			LibrarySearchResultRow(result: result)
				.transition(.opacity)
		}
	}

	var body: some View {
		scrollView
			.animation(.easeInOut(duration: 0.1), value: "\(searchPresented)\(searchTerm.isEmpty)")
			.buttonStyle(.plain)
			.searchable(
				text: searchBinding,
				isPresented: $searchPresented,
				placement: .toolbarPrincipal,
				prompt: "Search anything"
			)
			.searchPresentationToolbarBehavior(.avoidHidingContent)
			.onSubmit(of: .search) {
				IntentDonations.search(searchTerm)
			}
			.onChange(of: searchTerm, initial: true) { _, newValue in
				if !newValue.isEmpty {
					searchPresented = true
				}
			}
			.scrollEdgeEffectStyle(.soft, for: .all)
			.navigationBarTitleDisplayMode(.inline)
			.navigationTitle("Library")
			.toolbar {
				ToolbarItem(placement: .title) {
					Text("Library")
						.fontDesign(.rounded)
						.font(.title)
				}
			}
			.task(id: "\(searchPresented)-\(searchTerm.trimmingCharacters(in: .whitespacesAndNewlines))-\(catalog.isLoaded)") {
				let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
				guard searchPresented, !query.isEmpty, catalog.isLoaded else {
					// Only clear what's there, since every appearance of the tab runs this task
					if !searchResults.isEmpty {
						searchResults = []
					}
					return
				}
				do {
					try await Task.sleep(for: .milliseconds(120))
					let entries = libraryEntries
					let matches = try await CatalogSearch.ranked(
						entries,
						query: query,
						limit: CatalogSearch.resultLimit
					) { $0.searchFields }
					try Task.checkCancellation()
					searchResults = matches
				} catch is CancellationError {
					return
				} catch {
					searchResults = []
				}
			}
	}
}
