//
//  FallaciesView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import FuzzyMatch
import SwiftUI

struct FallaciesView: View {
	@Environment(CatalogStore.self) private var catalog

	@State private var tokens: [FallacyTag]

	init(initialFilter: FallacyTag? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""

	private var matchingTokens: [FallacyTag] {
		FallacyTag.allCases.filter { token in
			!tokens.contains(token) &&
				(
					searchTerm.isEmpty ||
						token.title.localizedStandardContains(searchTerm)
				)
		}
	}

	private func toggleToken(_ token: FallacyTag) {
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
						.accessibilityIdentifier("library.fallacies.filter.\(token.rawValue)")
					}
				}
			}

			results

			if !searchPresented {
				Text("\(catalog.fallacies.fallacies.count) fallacies")
					.font(.caption)
					.foregroundStyle(.secondary)
					.listRowBackground(Color.clear)
			}
		}
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
			prompt: "Search fallacies"
		) { token in
			Text(token.title)
		}
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Fallacies")
		.animation(.easeInOut(duration: 0.2), value: tokens)
	}

	private var filteredFallacies: [Fallacy] {
		let filtered = catalog.fallacies.fallacies.filter { fallacy in
			tokens.isEmpty ||
				tokens.contains { fallacy.tags.contains($0) }
		}

		return searchFallacies(
			filtered,
			query: searchPresented ? searchTerm : ""
		)
	}

	private var groupedFallacies: [(letter: String, fallacies: [Fallacy])] {
		let groups = Dictionary(grouping: filteredFallacies) {
			String($0.name.prefix(1)).uppercased()
		}

		return groups.keys.sorted().map { letter in
			(
				letter: letter,
				fallacies: groups[letter]!.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
			)
		}
	}

	@ViewBuilder
	var results: some View {
		if groupedFallacies.isEmpty {
			ContentUnavailableView.search(text: searchTerm)
		}
		ForEach(groupedFallacies, id: \.letter) { group in
			Section(group.letter) {
				ForEach(group.fallacies) { fallacy in
					NavigationLink(
						value: LibraryRoute.detail(
							category: .fallacies,
							id: fallacy.id
						)
					) {
						HStack {
							Label(fallacy.name, systemImage: fallacy.symbolName ?? "repeat.badge.xmark")
							Spacer()
						}
						.accessibilityIdentifier("library.fallacies.\(fallacy.id)")
					}
				}
			}
			.sectionIndexLabel(group.letter)
		}
	}

	var body: some View {
		main
			.toolbar {
				ToolbarItem(placement: .title) {
					Text("Fallacies")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(tokens.isEmpty ? .clear : .accent, in: Circle())
				}
			}
	}

	private var filterMenu: some View {
		Menu {
			ForEach(FallacyTag.allCases) { tag in
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
			.accessibilityIdentifier("library.fallacies.clearFilters")
		} label: {
			Label("Filters", systemImage: "line.3.horizontal.decrease")
				.labelStyle(.iconOnly)
		}
		.accessibilityIdentifier("library.fallacies.filters")
		.menuActionDismissBehavior(.disabled)
	}

	func searchFallacies(
		_ fallacies: [Fallacy],
		query: String
	) -> [Fallacy] {
		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return fallacies }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()

		return fallacies.compactMap { fallacy -> (Fallacy, Double)? in
			let fields = fallacy.searchFields

			let score = fields.compactMap { text, weight in
				matcher.score(
					text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * weight }
			}.max()

			guard let score else { return nil }
			return (fallacy, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}
}
