//
//  LibraryListRow.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import SwiftUI

/// One entry in a category's list, linking to its page, with a bookmark on a swipe or in its menu
struct LibraryListRow<Item: LibraryListItem>: View {
	let item: Item

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self) private var navigation

	@Default(.bookmarks) private var bookmarks

	var body: some View {
		let target = CatalogReference(
			id: item.id,
			name: item.name,
			category: Item.category
		)

		let isBookmarked = bookmarks.contains(target)

		return NavigationLink(
			value: LibraryRoute.detail(
				category: Item.category,
				id: item.id
			)
		) {
			HStack {
				item.row

				Spacer()

				if isBookmarked {
					Image(systemName: "bookmark")
						.foregroundStyle(.secondary)
						.symbolVariant(.fill)
				}
			}
			.accessibilityIdentifier("library.\(Item.category.rawValue).\(item.id)")
			.contextMenu {
				Button {
					toggleBookmark(target, isBookmarked: isBookmarked)
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
		.buttonStyle(.plain)
		.swipeActions(edge: .trailing) {
			Button {
				toggleBookmark(target, isBookmarked: isBookmarked)
			} label: {
				Label(
					isBookmarked ? "Remove Bookmark" : "Bookmark",
					systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
				)
			}
			.buttonStyle(.automatic)
			.tint(.accent)
		}
		.listedEntity(Item.Entity.self, id: item.id)
	}

	private func toggleBookmark(
		_ target: CatalogReference,
		isBookmarked: Bool
	) {
		IntentDonations.bookmark(target, added: !isBookmarked, catalog: catalog)

		withAnimation(.easeInOut) {
			if isBookmarked {
				bookmarks.remove(target)
			} else {
				bookmarks.insert(target)
			}
		}
	}
}
