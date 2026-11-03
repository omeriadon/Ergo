//
//  ArgumentsView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import SwiftUI

struct ArgumentsView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	@Environment(CatalogStore.self) private var catalog

	@State private var tokens: [ArgumentTag]

	init(initialFilter: ArgumentTag? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""
	@State private var searchedArguments: [Argument] = []

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
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: filteredArguments.map(\.id)
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
			prompt: "Search arguments"
		) { token in
			Text(token.title)
		}
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Arguments")
		.animation(.easeInOut(duration: 0.2), value: tokens)
	}

	private var filteredArguments: [Argument] {
		let isSearching = searchPresented && !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		let source = isSearching
			? searchedArguments
			: catalog.arguments.arguments

		let filtered = source.filter { argument in
			tokens.isEmpty ||
				tokens.contains { argument.tags.contains($0) }
		}

		return isSearching ? Array(filtered.prefix(CatalogSearch.resultLimit)) : filtered
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
		let groups = groupedArguments

		if groups.isEmpty {
			ContentUnavailableView.search(text: searchTerm)
		}
		ForEach(groups, id: \.letter) { group in
			Section(group.letter) {
				ForEach(group.arguments) { argument in
					NavigationLink(
						value: LibraryRoute.detail(
							category: .arguments,
							id: argument.id
						)
					) {
						let target = CatalogReference(id: argument.id, name: argument.name, category: .arguments)

						let isBookmarked = bookmarks.contains(target)

						HStack {
							Label(argument.name, systemImage: argument.symbolName ?? "text.bubble")
							Spacer()
						}
						.accessibilityIdentifier("library.arguments.\(argument.id)")
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
					Text("Arguments")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(tokens.isEmpty ? .clear : .accent, in: Circle())
				}
			}
			.task(id: "\(searchPresented)-\(searchTerm.trimmingCharacters(in: .whitespacesAndNewlines))-\(catalog.isLoaded)") {
				let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
				guard searchPresented, !query.isEmpty, catalog.isLoaded else {
					searchedArguments = []
					return
				}
				do {
					try await Task.sleep(for: .milliseconds(120))
					let matches = try await CatalogSearch.ranked(
						catalog.arguments.arguments,
						query: query,
						limit: CatalogSearch.resultLimit
					) { $0.searchFields }
					try Task.checkCancellation()
					searchedArguments = matches
				} catch is CancellationError {
					return
				} catch {
					searchedArguments = []
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
}
