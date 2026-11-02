//
//  RazorsView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import FuzzyMatch
import SwiftUI

struct RazorsView: View {
	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var tokens: [RazorTag]

	init(initialFilter: RazorTag? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""

	private var matchingTokens: [RazorTag] {
		RazorTag.allCases.filter { token in
			!tokens.contains(token) &&
				(
					searchTerm.isEmpty ||
						token.title.localizedStandardContains(searchTerm)
				)
		}
	}

	private var suggestedTokens: Binding<[RazorTag]> {
		Binding(
			get: { matchingTokens },
			set: { _ in }
		)
	}

	private func toggleToken(_ token: RazorTag) {
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
				Text("\(catalog.razors.razors.count) razors")
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
			prompt: "Search razors"
		) { token in
			Text(token.title)
		}
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Razors")
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

	private var filteredRazors: [Razor] {
		let filtered = catalog.razors.razors.filter { razor in
			tokens.isEmpty ||
				tokens.contains { razor.tags.contains($0) }
		}

		return searchRazors(
			filtered,
			query: searchPresented ? searchTerm : ""
		)
	}

	private var groupedRazors: [(letter: String, razors: [Razor])] {
		let groups = Dictionary(grouping: filteredRazors) {
			String($0.name.prefix(1)).uppercased()
		}

		return groups.keys.sorted().map { letter in
			(
				letter: letter,
				razors: groups[letter]!.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
			)
		}
	}

	var results: some View {
		ForEach(groupedRazors, id: \.letter) { group in
			Section(group.letter) {
				ForEach(group.razors) { razor in
					NavigationLink(
						value: LibraryRoute.detail(
							category: .razors,
							id: razor.id
						)
					) {
						HStack {
							Label(razor.name, systemImage: "scissors")
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
					Text("Razors")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(tokens.isEmpty ? .clear : .accent, in: Circle())
				}
			}
	}

	private var filterMenu: some View {
		Menu {
			ForEach(RazorTag.allCases) { tag in
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

	func searchRazors(
		_ razors: [Razor],
		query: String
	) -> [Razor] {
		guard !query.isEmpty else { return razors }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()

		return razors.compactMap { razor -> (Razor, Double)? in
			let fields: [(String, Double)] = [
				(razor.name, 1.0),
				(razor.body, 0.5),
				(razor.summary, 0.5),
			] + razor.aliases.map { ($0, 0.9) }

			let score = fields.compactMap { text, weight in
				matcher.score(
					text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * weight }
			}.max()

			guard let score else { return nil }
			return (razor, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}
}
