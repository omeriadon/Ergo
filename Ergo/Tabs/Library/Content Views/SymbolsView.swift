//
//  SymbolsView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import FuzzyMatch
import SwiftUI

struct SymbolsView: View {
	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var tokens: [SymbolSearchToken]

	init(initialFilter: SymbolSearchToken? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""

	private var matchingTokens: [SymbolSearchToken] {
		let allTokens: [SymbolSearchToken] =
			SymbolGroup.allCases.map { .group($0) } +
			SymbolTag.allCases.map { .tag($0) }

		return allTokens.filter { token in
			!tokens.contains(token) &&
				(
					searchTerm.isEmpty ||
						token.title.localizedStandardContains(searchTerm)
				)
		}
	}

	private var suggestedTokens: Binding<[SymbolSearchToken]> {
		Binding(
			get: { matchingTokens },
			set: { _ in }
		)
	}

	private var selectedGroups: Set<SymbolGroup> {
		Set(tokens.compactMap {
			guard case let .group(group) = $0 else { return nil }
			return group
		})
	}

	private var selectedTags: Set<SymbolTag> {
		Set(tokens.compactMap {
			guard case let .tag(tag) = $0 else { return nil }
			return tag
		})
	}

	private func toggleToken(_ token: SymbolSearchToken) {
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
							Label(token.title, systemImage: token.symbol)
						}
					}
				}
			}

			results

			if !searchPresented {
				Text("\(catalog.logicSymbols.symbols.count) symbols")
					.font(.caption)
					.foregroundStyle(.secondary)
					.listRowBackground(Color.clear)
			}
		}
		.animation(.easeInOut(duration: 0.2), value: searchPresented)
		.scrollEdgeEffectStyle(.soft, for: .all)
		.buttonStyle(.plain)
		.toolbarMinimizationBehavior(.never, for: .navigationBar)
		.searchable(
			text: $searchTerm,
			tokens: $tokens,
			isPresented: $searchPresented,
			placement: .navigationBarDrawer(displayMode: .always),
			prompt: "Search logic symbols"
		) { token in
			Text(token.title)
		}
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Symbols")
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
							Image(systemName: token.symbol)
						}
					}
				}
			}
		}

		results
	}

	private var filteredSymbols: [LogicSymbol] {
		let groups = selectedGroups
		let tags = selectedTags

		let filtered = catalog.logicSymbols.symbols.filter { symbol in
			let groupMatches =
				groups.isEmpty ||
				groups.contains(symbol.group)

			let tagMatches =
				tags.isEmpty ||
				!tags.isDisjoint(with: symbol.tags)

			return groupMatches && tagMatches
		}

		return searchSymbols(
			filtered,
			query: searchPresented ? searchTerm : ""
		)
	}

	var results: some View {
		ForEach(SymbolGroup.allCases) { group in
			let symbols = filteredSymbols.filter { $0.group == group }

			if !symbols.isEmpty {
				Section(group.rawValue.capitalized) {
					ForEach(symbols) { symbol in
						NavigationLink(
							value: LibraryRoute.detail(
								category: .symbols,
								id: symbol.id
							)
						) {
							HStack {
								Text(symbol.glyph)
									.font(.title)
									.fontDesign(.monospaced)
									.foregroundStyle(.accent)
									.frame(
										width: symbol.glyph.count < 3 ? 40 : 110,
										alignment: .leading
									)

								Text(symbol.name)
								Spacer()
							}
						}
					}
				}
			}
		}
	}

	var body: some View {
		main
			.toolbar {
				ToolbarItem(placement: .title) {
					Text("Symbols")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(tokens.isEmpty ? .clear : .accent, in: Circle())
				}
			}
	}

	private var filterMenu: some View {
		Menu {
			Menu("Groups", systemImage: "square.grid.2x2") {
				ForEach(SymbolGroup.allCases) { group in
					Toggle(
						group.rawValue.capitalized,
						isOn: Binding(
							get: { tokens.contains(.group(group)) },
							set: { _ in toggleToken(.group(group)) }
						)
					)
				}
			}
			.menuActionDismissBehavior(.disabled)

			Menu("Tags", systemImage: "tag") {
				ForEach(SymbolTag.allCases) { tag in
					Toggle(
						tag.rawValue.capitalized,
						isOn: Binding(
							get: { tokens.contains(.tag(tag)) },
							set: { _ in toggleToken(.tag(tag)) }
						)
					)
				}
			}
			.menuActionDismissBehavior(.disabled)

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
	}

	func searchSymbols(
		_ symbols: [LogicSymbol],
		query: String
	) -> [LogicSymbol] {
		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return symbols }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()

		return symbols.compactMap { symbol -> (LogicSymbol, Double)? in
			let fields = symbol.searchFields

			let score = fields.compactMap { text, weight in
				matcher.score(
					text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * weight }
			}.max()

			guard let score else { return nil }
			return (symbol, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}
}
