//
//  RazorDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import SwiftUI

struct RazorDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	@State private var hasScrolled = false
	@State private var isOpening = true

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var conf = detailViewConf
				conf.palette = [
					Color.yellow.toSIMD3,
					Color.yellow.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let razor = catalog.razors.razors.first(where: { $0.id == id }) {
				ScrollView {
					LazyVStack(alignment: .leading) {
						AliasTitle(name: razor.name, aliases: razor.aliases)

						Spacer()
							.frame(height: 10)

						Text(razor.summary)
							.textSelection(.enabled)
							.lineLimit(10)
							.bounceOnAppear(after: 1)

						VStack {
							Image(systemName: "quote.opening")
								.frame(maxWidth: .infinity, alignment: .leading)

							Text(razor.lensQuestion)
								.font(.title3)
								.textSelection(.enabled)
								.padding(.horizontal, 24)
								.frame(maxWidth: .infinity, alignment: .center)

							Image(systemName: "quote.closing")
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
						.padding(12)
						.frame(maxWidth: .infinity, alignment: .leading)
						.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
						.padding(.vertical, 20)
						.bounceOnAppear(after: 2)

						Text(razor.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.bounceOnAppear(after: 3)

						ExamplesSection(list: razor.examples)
							.padding(.top)
							.bounceOnAppear(after: 4)

						NotesSection(list: razor.limitations)
							.padding(.top)
							.bounceOnAppear(after: 5)

						RelatedSection(list: razor.related)
							.padding(.top)
							.bounceOnAppear(after: 6)

						TagSection(list: razor.tags.map { tag in
							CatalogTag(
								id: "razors.\(tag.rawValue)",
								title: tag.title,
								route: .razors(filter: tag)
							)
						})
						.padding(.top)
						.bounceOnAppear(after: 7)

						Spacer()
							.frame(height: 40)
					}
					.padding(.horizontal)
					.frame(maxWidth: .infinity, alignment: .leading)
					.environment(\.isOpeningDetail, isOpening)
				}
				.task {
					try? await Task.sleep(for: .milliseconds(200))
					isOpening = false
				}
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(razor.name, category: "Razors", hasScrolled: hasScrolled)
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(razor.name.capitalized)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					ToolbarItem(placement: .topBarTrailing) {
						let reference = CatalogReference(
							id: razor.id,
							name: razor.name,
							category: .razors
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
				Text("Razor not found")

				Button {
					navigation.libraryPath.removeLast()
				} label: {
					Text("Go Back")
				}
			}
		}
	}
}
