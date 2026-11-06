//
//  ParadoxDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import SwiftUI

struct ParadoxDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	@State private var hasScrolled = false

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var conf = detailViewConf
				conf.palette = [
					Color.mint.toSIMD3,
					Color.mint.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let paradox = catalog.paradoxes.paradoxes.first(where: { $0.id == id }) {
				ScrollView {
					VStack(alignment: .leading) {
						AliasTitle(name: paradox.name, aliases: paradox.aliases)

						Spacer()
							.frame(height: 10)

						Text(paradox.summary)
							.textSelection(.enabled)
							.lineLimit(10)

						RelatedSection(list: paradox.keyFigures, title: "Key Figures")
							.padding(.top)

						Spacer()
							.frame(height: 20)

						Text(paradox.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

						if let origin = paradox.origin, !origin.isEmpty {
							NotesSection(list: [origin], title: "Origin")
								.padding(.top)
						}

						ExamplesSection(list: paradox.examples)
							.padding(.top)

						NotesSection(list: paradox.commonMisreadings, title: "Common Misreadings")
							.padding(.top)

						NotesSection(list: paradox.criticisms, title: "Criticisms")
							.padding(.top)

						LookalikeSection(list: paradox.lookalikes)
							.padding(.top)

						RelatedSection(list: paradox.related)
							.padding(.top)

						TagSection(list: paradox.tags.map { tag in
							CatalogTag(
								id: "paradoxes.\(tag.rawValue)",
								title: tag.title,
								route: .paradoxes(filter: tag)
							)
						})
						.padding(.top)

						Spacer()
							.frame(height: 40)
					}
					.padding(.horizontal)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(paradox.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(paradox.name, category: "Paradoxes", hasScrolled: hasScrolled)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					ToolbarItem(placement: .topBarTrailing) {
						let reference = CatalogReference(
							id: paradox.id,
							name: paradox.name,
							category: .paradoxes
						)

						let isBookmarked = bookmarks.contains(reference)

						Button {
							IntentDonations.bookmark(reference, added: !isBookmarked, catalog: catalog)

							withAnimation(.easeInOut) {
								if isBookmarked {
									bookmarks.remove(reference)
								} else {
									bookmarks.insert(reference)
								}
							}
						} label: {
							Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
								.contentTransition(.symbolEffect(.replace))
						}
						.buttonStyle(.glassProminent)
						.tint(isBookmarked ? .accentColor : .clear)
					}
				}

			} else {
				Text("Paradox not found")

				Button {
					navigation.libraryPath.removeLast()
				} label: {
					Text("Go Back")
				}
			}
		}
	}
}
