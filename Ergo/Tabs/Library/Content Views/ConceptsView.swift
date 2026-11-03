//
//  ConceptsView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import SwiftUI

struct ConceptsView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	@State private var tokens: [ConceptTag]

	init(initialFilter: ConceptTag? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""
	@State private var searchedConcepts: [Concept] = []

	private var matchingTokens: [ConceptTag] {
		ConceptTag.allCases.filter { token in
			!tokens.contains(token) &&
				(
					searchTerm.isEmpty ||
						token.title.localizedStandardContains(searchTerm)
				)
		}
	}

	private func toggleToken(_ token: ConceptTag) {
		withAnimation(.easeInOut(duration: 0.2)) {
			if tokens.contains(token) {
				tokens.removeAll { $0 == token }
			} else {
				tokens.append(token)
			}
		}
	}

	@State private var searchPresented = false

	var main: some View {
		List {
			if searchPresented, !matchingTokens.isEmpty {
				Section("Filters") {
					ForEach(matchingTokens) { token in
						Button {
							toggleToken(token)
							searchTerm = ""
						} label: {
							Label(token.title, systemImage: "tag")
						}
						.accessibilityIdentifier("library.concepts.filter.\(token.rawValue)")
					}
				}
			}

			results

			if !searchPresented {
				Text("\(catalog.concepts.concepts.count) concepts")
					.font(.caption)
					.foregroundStyle(.secondary)
					.listRowBackground(Color.clear)
			}
		}
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: filteredConcepts.map(\.id)
		)
		.animation(.easeInOut(duration: 0.2), value: searchPresented)
		.listSectionIndexVisibility(.visible)
		.scrollEdgeEffectStyle(.soft, for: .all)
		.buttonStyle(.plain)
		.toolbarMinimizationBehavior(.never, for: .navigationBar)
		.searchable(
			text: $searchTerm,
			tokens: $tokens,
			isPresented: $searchPresented,
			placement: .navigationBarDrawer(displayMode: .always),
			prompt: "Search concepts"
		) { token in
			Text(token.title)
		}
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Concepts")
		.animation(.easeInOut(duration: 0.2), value: tokens)
	}

	private var filteredConcepts: [Concept] {
		let isSearching = searchPresented && !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		let source = isSearching
			? searchedConcepts
			: catalog.concepts.concepts

		let filtered = source.filter { concept in
			tokens.isEmpty ||
				tokens.contains { concept.tags.contains($0) }
		}

		return isSearching ? Array(filtered.prefix(CatalogSearch.resultLimit)) : filtered
	}

	private var groupedConcepts: [(letter: String, concepts: [Concept])] {
		let groups = Dictionary(grouping: filteredConcepts) {
			String($0.name.prefix(1)).uppercased()
		}

		return groups.keys.sorted().map { letter in
			(
				letter: letter,
				concepts: groups[letter]!.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
			)
		}
	}

	@ViewBuilder
	var results: some View {
		let groups = groupedConcepts

		if groups.isEmpty {
			ContentUnavailableView.search(text: searchTerm)
		}
		ForEach(groups, id: \.letter) { group in
			Section(group.letter) {
				ForEach(group.concepts) { concept in
					NavigationLink(
						value: LibraryRoute.detail(
							category: .concepts,
							id: concept.id
						)
					) {
						let target = CatalogReference(id: concept.id, name: concept.name, category: .concepts)

						let isBookmarked = bookmarks.contains(target)

						HStack {
							Label(concept.name, systemImage: concept.symbolName ?? "book.closed")
							Spacer()

							if isBookmarked {
								Image(systemName: "bookmark")
									.foregroundStyle(.secondary)
									.symbolVariant(.fill)
							}
						}
						.accessibilityIdentifier("library.concepts.\(concept.id)")
						.contextMenu {
							Button {
								withAnimation(.easeInOut) {
									if isBookmarked {
										bookmarks.remove(target)
									} else {
										bookmarks.insert(target)
									}
								}
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
					.transition(.opacity)
				}
			}
			.sectionIndexLabel(group.letter)
		}
	}

	var body: some View {
		main
			.toolbar {
				ToolbarItem(placement: .title) {
					Text("Concepts")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(tokens.isEmpty ? .clear : .accent, in: Circle())
				}
			}
			.task(id: "\(searchPresented)-\(searchTerm.trimmingCharacters(in: .whitespacesAndNewlines))-\(catalog.isLoaded)") {
				let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
				guard searchPresented, !query.isEmpty, catalog.isLoaded else {
					searchedConcepts = []
					return
				}
				do {
					try await Task.sleep(for: .milliseconds(120))
					let matches = try await CatalogSearch.ranked(
						catalog.concepts.concepts,
						query: query
					) { $0.searchFields }
					try Task.checkCancellation()
					searchedConcepts = matches
				} catch is CancellationError {
					return
				} catch {
					searchedConcepts = []
				}
			}
	}

	private var filterMenu: some View {
		Menu {
			ForEach(ConceptTag.allCases) { tag in
				Toggle(
					tag.title.capitalized,
					isOn: Binding(
						get: { tokens.contains(tag) },
						set: { _ in toggleToken(tag) }
					)
				)
			}

			Divider()

			Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle") {
				withAnimation(.easeInOut(duration: 0.2)) {
					tokens.removeAll()
				}
			}
			.disabled(tokens.isEmpty)
			.accessibilityIdentifier("library.concepts.clearFilters")
		} label: {
			Label("Filters", systemImage: "line.3.horizontal.decrease")
				.labelStyle(.iconOnly)
		}
		.accessibilityIdentifier("library.concepts.filters")
		.menuActionDismissBehavior(.disabled)
	}
}
