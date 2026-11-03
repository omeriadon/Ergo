//
//  SymbolsView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import SwiftUI

struct SymbolsView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	@State private var tokens: [SymbolSearchToken]

	init(initialFilter: SymbolSearchToken? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""
	@State private var searchedSymbols: [LogicSymbol] = []

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
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: filteredSymbols.map(\.id)
		)
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

		let isSearching = searchPresented && !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		let source = isSearching
			? searchedSymbols
			: catalog.logicSymbols.symbols

		let filtered = source.filter { symbol in
			let groupMatches =
				groups.isEmpty ||
				groups.contains(symbol.group)

			let tagMatches =
				tags.isEmpty ||
				!tags.isDisjoint(with: symbol.tags)

			return groupMatches && tagMatches
		}

		return isSearching ? Array(filtered.prefix(CatalogSearch.resultLimit)) : filtered
	}

	var results: some View {
		let filtered = filteredSymbols

		return ForEach(SymbolGroup.allCases) { group in
			let symbols = filtered.filter { $0.group == group }

			if !symbols.isEmpty {
				Section(group.rawValue.capitalized) {
					ForEach(symbols) { symbol in
						NavigationLink(
							value: LibraryRoute.detail(
								category: .symbols,
								id: symbol.id
							)
						) {
							let target = CatalogReference(id: symbol.id, name: symbol.name, category: .symbols)

							let isBookmarked = bookmarks.contains(target)

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

								if isBookmarked {
									Image(systemName: "bookmark")
										.foregroundStyle(.secondary)
										.symbolVariant(.fill)
								}
							}
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
			.task(id: "\(searchPresented)-\(searchTerm.trimmingCharacters(in: .whitespacesAndNewlines))-\(catalog.isLoaded)") {
				let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
				guard searchPresented, !query.isEmpty, catalog.isLoaded else {
					searchedSymbols = []
					return
				}
				do {
					try await Task.sleep(for: .milliseconds(120))
					let matches = try await CatalogSearch.ranked(
						catalog.logicSymbols.symbols,
						query: query,
						limit: CatalogSearch.resultLimit
					) { $0.searchFields }
					try Task.checkCancellation()
					searchedSymbols = matches
				} catch is CancellationError {
					return
				} catch {
					searchedSymbols = []
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
}
