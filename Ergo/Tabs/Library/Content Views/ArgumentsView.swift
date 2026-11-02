//
//  ArgumentsView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import FuzzyMatch
import SwiftUI

struct ArgumentsView: View {
	@Environment(CatalogStore.self) private var catalog

	@State private var tokens: [ArgumentTag]

	init(initialFilter: ArgumentTag? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""

	private var matchingTokens: [ArgumentTag] {
		ArgumentTag.allCases.filter { token in
			!tokens.contains(token) &&
				(
					searchTerm.isEmpty ||
						token.title.localizedStandardContains(searchTerm)
				)
		}
	}

	private func toggleToken(_ token: ArgumentTag) {
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
						.accessibilityIdentifier("library.arguments.filter.\(token.rawValue)")
					}
				}
			}

			results

			if !searchPresented {
				Text("\(catalog.arguments.arguments.count) arguments")
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
			prompt: "Search arguments"
		) { token in
			Text(token.title)
		}
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Arguments")
		.animation(.easeInOut(duration: 0.2), value: tokens)
	}

	private var filteredArguments: [Argument] {
		let filtered = catalog.arguments.arguments.filter { argument in
			tokens.isEmpty ||
				tokens.contains { argument.tags.contains($0) }
		}

		return searchArguments(
			filtered,
			query: searchPresented ? searchTerm : ""
		)
	}

	private var groupedArguments: [(letter: String, arguments: [Argument])] {
		let groups = Dictionary(grouping: filteredArguments) {
			String($0.name.prefix(1)).uppercased()
		}

		return groups.keys.sorted().map { letter in
			(
				letter: letter,
				arguments: groups[letter]!.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
			)
		}
	}

	@ViewBuilder
	var results: some View {
		if groupedArguments.isEmpty {
			ContentUnavailableView.search(text: searchTerm)
		}
		ForEach(groupedArguments, id: \.letter) { group in
			Section(group.letter) {
				ForEach(group.arguments) { argument in
					NavigationLink(
						value: LibraryRoute.detail(
							category: .arguments,
							id: argument.id
						)
					) {
						HStack {
							Label(argument.name, systemImage: argument.symbolName ?? "text.bubble")
							Spacer()
						}
						.accessibilityIdentifier("library.arguments.\(argument.id)")
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
					Text("Arguments")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(tokens.isEmpty ? .clear : .accent, in: Circle())
				}
			}
	}

	private var filterMenu: some View {
		Menu {
			ForEach(ArgumentTag.allCases) { tag in
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
			.accessibilityIdentifier("library.arguments.clearFilters")
		} label: {
			Label("Filters", systemImage: "line.3.horizontal.decrease")
				.labelStyle(.iconOnly)
		}
		.accessibilityIdentifier("library.arguments.filters")
		.menuActionDismissBehavior(.disabled)
	}

	func searchArguments(
		_ arguments: [Argument],
		query: String
	) -> [Argument] {
		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return arguments }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()

		return arguments.compactMap { argument -> (Argument, Double)? in
			let fields = argument.searchFields

			let score = fields.compactMap { text, weight in
				matcher.score(
					text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * weight }
			}.max()

			guard let score else { return nil }
			return (argument, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}
}
