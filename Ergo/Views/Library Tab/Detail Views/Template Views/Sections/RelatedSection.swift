//
//  RelatedSection.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import SwiftUI

struct RelatedSection: View {
	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	let list: [CatalogReference]
	var title = "Related"

	@Default(.bookmarks) var bookmarks

	var body: some View {
		if !list.isEmpty {
			if list.allSatisfy({ $0.category == .philosophers }) {
				VStack(alignment: .leading, spacing: 20) {
					Text(title)
						.textCase(.uppercase)
						.font(.title3)
						.foregroundStyle(.secondary)

					ForEach(Array(list.enumerated()), id: \.element.id) { index, philosopher in
						NavigationLink(value: philosopher.route) {
							HStack {
								PhilosopherThumbnail(id: philosopher.id)
									.frame(width: 40, height: 40)

								Text(philosopher.name)

								Image(systemName: "chevron.right")
									.imageScale(.small)
							}
							.tint(.primary)
							.padding(.leading, CGFloat(index) * 40)
						}
					}
				}
				.padding(.vertical, 20)
				.padding(.horizontal, 25)
				.frame(maxWidth: .infinity, alignment: .leading)
				.glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 30))
				.padding(.top)

			} else {
				VStack(alignment: .leading, spacing: 13) {
					Text(title)
						.textCase(.uppercase)
						.foregroundStyle(.secondary)

					VStack(alignment: .leading, spacing: 10) {
						ForEach(list, id: \.id) { target in
							let isBookmarked = bookmarks.contains(target)

							NavigationLink(value: target.route) {
								HStack {
									Text(target.name)
									Spacer()
									Image(systemName: "chevron.right")
								}
								.contextMenu {
									Button {
										IntentDonations.bookmark(target, added: !isBookmarked, catalog: catalog)

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
						}
					}
				}
				.padding(12)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
			}
		}
	}
}
