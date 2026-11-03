//
//  RazorsView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import SwiftUI

struct RazorsView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	@State private var tokens: [RazorTag]

	init(initialFilter: RazorTag? = nil) {
		_tokens = State(initialValue: initialFilter.map { [$0] } ?? [])
	}

	@State private var searchTerm = ""
	@State private var searchedRazors: [Razor] = []

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
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: filteredRazors.map(\.id)
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
		let isSearching = searchPresented && !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		let source = isSearching
			? searchedRazors
			: catalog.razors.razors

		let filtered = source.filter { razor in
			tokens.isEmpty ||
				tokens.contains { razor.tags.contains($0) }
		}

		return isSearching ? Array(filtered.prefix(CatalogSearch.resultLimit)) : filtered
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
						let target = CatalogReference(id: razor.id, name: razor.name, category: .razors)

						let isBookmarked = bookmarks.contains(target)

						HStack {
							Label(razor.name, systemImage: "scissors")
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
			.task(id: "\(searchPresented)-\(searchTerm.trimmingCharacters(in: .whitespacesAndNewlines))-\(catalog.isLoaded)") {
				let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
				guard searchPresented, !query.isEmpty, catalog.isLoaded else {
					searchedRazors = []
					return
				}
				do {
					try await Task.sleep(for: .milliseconds(120))
					let matches = try await CatalogSearch.ranked(
						catalog.razors.razors,
						query: query
					) { $0.searchFields }
					try Task.checkCancellation()
					searchedRazors = matches
				} catch is CancellationError {
					return
				} catch {
					searchedRazors = []
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
}
