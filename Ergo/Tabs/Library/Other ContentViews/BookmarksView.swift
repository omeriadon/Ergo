//
//  BookmarksView.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import Defaults
import SwiftUI

struct BookmarksView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Default(.bookmarks) private var bookmarks

	@State private var selectedCategories: Set<LibraryContent> = []

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(CatalogStore.self) private var catalog

	private var availableCategories: [LibraryContent] {
		Set(bookmarks.map(\.category))
			.sorted {
				$0.rawValue.localizedStandardCompare($1.rawValue) == .orderedAscending
			}
	}

	private var filteredBookmarks: [CatalogReference] {
		bookmarks.filter {
			selectedCategories.isEmpty ||
				selectedCategories.contains($0.category)
		}
	}

	private var groupedBookmarks: [(category: LibraryContent, bookmarks: [CatalogReference])] {
		let groups = Dictionary(
			grouping: filteredBookmarks,
			by: \.category
		)

		return groups.keys.sorted {
			$0.rawValue.localizedStandardCompare($1.rawValue) == .orderedAscending
		}.map { category in
			(
				category: category,
				bookmarks: groups[category]!.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
			)
		}
	}

	private var visibleBookmarkIDs: [String] {
		groupedBookmarks.flatMap { $0.bookmarks.map(\.id) }
	}

	private var main: some View {
		List {
			if groupedBookmarks.isEmpty {
				ContentUnavailableView("No Bookmarks", systemImage: "bookmark")
					.listRowBackground(Color.clear)
					.padding(.top, 100)
			} else {
				results
			}
		}
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: visibleBookmarkIDs
		)
		.listSectionIndexVisibility(.visible)
		.scrollEdgeEffectStyle(.soft, for: .all)
		.buttonStyle(.plain)
		.navigationBarTitleDisplayMode(.inline)
		.scrollDisabled(groupedBookmarks.isEmpty)
		.toolbarMinimizationBehavior(.never, for: .navigationBar)
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Bookmarks")
	}

	private var results: some View {
		ForEach(groupedBookmarks, id: \.category) { group in
			Section(group.category.rawValue.capitalized) {
				ForEach(group.bookmarks) { bookmark in
					NavigationLink(value: bookmark.route) {
						HStack {
							Image(systemName: bookmark.category.symbol)
								.foregroundStyle(.accent)
							Text(bookmark.name)
							Spacer()
						}
						.contextMenu {
							let isBookmarked = bookmarks.contains(bookmark)

							Button {
								withAnimation(.easeInOut) {
									if isBookmarked {
										bookmarks.remove(bookmark)
									} else {
										bookmarks.insert(bookmark)
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
							LibraryDetailView(category: bookmark.category, id: bookmark.id)
								.environment(catalog)
								.environment(navigation)
						}
					}
					.transition(.opacity)
				}
			}
			.sectionIndexLabel(
				String(group.category.rawValue.prefix(1)).uppercased()
			)
		}
	}

	var body: some View {
		main
			.toolbar {
				ToolbarItem(placement: .title) {
					Text("Bookmarks")
				}

				ToolbarItem(placement: .topBarTrailing) {
					filterMenu
						.background(
							selectedCategories.isEmpty ? .clear : .accent,
							in: Circle()
						)
				}
			}
	}

	private var filterMenu: some View {
		Menu {
			ForEach(availableCategories, id: \.self) { category in
				Toggle(
					category.rawValue.capitalized,
					isOn: Binding(
						get: {
							selectedCategories.contains(category)
						},
						set: { isSelected in
							if isSelected {
								selectedCategories.insert(category)
							} else {
								selectedCategories.remove(category)
							}
						}
					)
				)
			}

			Divider()

			Button("Clear Filters") {
				withAnimation(.easeInOut(duration: 0.2)) {
					selectedCategories.removeAll()
				}
			}
			.disabled(selectedCategories.isEmpty)
		} label: {
			Image(systemName: "line.3.horizontal.decrease")
		}
		.menuActionDismissBehavior(.disabled)
	}
}
