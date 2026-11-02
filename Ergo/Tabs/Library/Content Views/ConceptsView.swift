//
//  ConceptsView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import FuzzyMatch
import SwiftUI

struct ConceptsView: View {
	@Environment(CatalogStore.self) private var catalog

	@State private var tokens: [ConceptTag]

	init(initialFilter: ConceptTag? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""

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
		let filtered = catalog.concepts.concepts.filter { concept in
			tokens.isEmpty ||
				tokens.contains { concept.tags.contains($0) }
		}

		return searchConcepts(
			filtered,
			query: searchPresented ? searchTerm : ""
		)
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
		if groupedConcepts.isEmpty {
			ContentUnavailableView.search(text: searchTerm)
		}
		ForEach(groupedConcepts, id: \.letter) { group in
			Section(group.letter) {
				ForEach(group.concepts) { concept in
					NavigationLink(
						value: LibraryRoute.detail(
							category: .concepts,
							id: concept.id
						)
					) {
						HStack {
							Label(concept.name, systemImage: concept.symbolName ?? "book.closed")
							Spacer()
						}
						.accessibilityIdentifier("library.concepts.\(concept.id)")
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
					Text("Concepts")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(tokens.isEmpty ? .clear : .accent, in: Circle())
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

	func searchConcepts(
		_ concepts: [Concept],
		query: String
	) -> [Concept] {
		guard !query.isEmpty else { return concepts }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()

		return concepts.compactMap { concept -> (Concept, Double)? in
			let fields: [(String, Double)] = [
				(concept.name, 1.0),
				(concept.body, 0.5),
				(concept.summary, 0.5),
			] + concept.aliases.map { ($0, 0.9) }

			let score = fields.compactMap { text, weight in
				matcher.score(
					text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * weight }
			}.max()

			guard let score else { return nil }
			return (concept, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}
}
