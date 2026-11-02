//
//  BiasesView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import FuzzyMatch
import SwiftUI

struct BiasesView: View {
	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var tokens: [BiasTag]

	init(initialFilter: BiasTag? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""

	private var matchingTokens: [BiasTag] {
		BiasTag.allCases.filter { token in
			!tokens.contains(token) &&
				(
					searchTerm.isEmpty ||
						token.title.localizedStandardContains(searchTerm)
				)
		}
	}

	private var suggestedTokens: Binding<[BiasTag]> {
		Binding(
			get: { matchingTokens },
			set: { _ in }
		)
	}

	private func toggleToken(_ token: BiasTag) {
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
					}
				}
			}

			results

			if !searchPresented {
				Text("\(catalog.biases.biases.count) biases")
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
			prompt: "Search biases"
		) { token in
			Text(token.title)
		}
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Biases")
		.animation(.easeInOut(duration: 0.2), value: tokens)
	}

	@ContentBuilder
	var searchPresentedView: some View {
		if !matchingTokens.isEmpty {
			Section("Filters") {
				ForEach(matchingTokens) { token in
					Button {
						tokens.append(token)
						searchTerm = ""
					} label: {
						Label {
							Text(token.title)
						} icon: {
							Image(systemName: "tag")
						}
					}
				}
			}
		}

		results
	}

	private var filteredBiases: [Bias] {
		let filtered = catalog.biases.biases.filter { bias in
			tokens.isEmpty ||
				tokens.contains { bias.tags.contains($0) }
		}

		return searchBiases(
			filtered,
			query: searchPresented ? searchTerm : ""
		)
	}

	private var groupedBiases: [(letter: String, biases: [Bias])] {
		let groups = Dictionary(grouping: catalog.biases.biases) {
			String($0.name.prefix(1)).uppercased()
		}

		return groups.keys.sorted().map { letter in
			(
				letter: letter,
				biases: groups[letter]!.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
			)
		}
	}

	var results: some View {
		ForEach(groupedBiases, id: \.letter) { group in
			Section(group.letter) {
				ForEach(group.biases) { bias in
					NavigationLink(
						value: LibraryRoute.detail(
							category: .biases,
							id: bias.id
						)
					) {
						HStack {
							Text(bias.name)
							Spacer()
						}
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
					Text("Biases")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(tokens.isEmpty ? .clear : .accent, in: Circle())
				}
			}
	}

	private var filterMenu: some View {
		Menu {
			ForEach(BiasTag.allCases) { tag in
				Toggle(
					tag.title.capitalized,
					isOn: Binding(
						get: { tokens.contains(tag) },
						set: { _ in toggleToken(tag) }
					)
				)
			}

			Divider()

			Button("Clear Filters") {
				withAnimation(.easeInOut(duration: 0.2)) {
					tokens.removeAll()
				}
			}
			.disabled(tokens.isEmpty)
		} label: {
			Image(systemName: "line.3.horizontal.decrease")
		}
		.menuActionDismissBehavior(.disabled)
	}

	func searchBiases(
		_ biases: [Bias],
		query: String
	) -> [Bias] {
		guard !query.isEmpty else { return biases }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()

		return biases.compactMap { bias -> (Bias, Double)? in
			let fields: [(String, Double)] = [
				(bias.name, 1.0),
				(bias.body, 0.5),
				(bias.summary, 0.5),
			] + bias.aliases.map { ($0, 0.9) }

			let score = fields.compactMap { text, weight in
				matcher.score(
					text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * weight }
			}.max()

			guard let score else { return nil }
			return (bias, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}
}
