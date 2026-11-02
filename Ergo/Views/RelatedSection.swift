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

	@Default(.bookmarks) var bookmarks

	var body: some View {
		if !list.isEmpty {
			VStack(alignment: .leading, spacing: 13) {
				Text("Related")
					.textCase(.uppercase)
					.foregroundStyle(.accent.secondary)

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
