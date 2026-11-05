//
//  BiasDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import SwiftUI

struct BiasDetailView: View {
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
					Color.red.toSIMD3,
					Color.red.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let bias = catalog.biases.biases.first(where: { $0.id == id }) {
				ScrollView {
					VStack(alignment: .leading) {
						AliasTitle(name: bias.name, aliases: bias.aliases)

						Spacer()
							.frame(height: 10)

						Text(bias.summary)
							.lineLimit(10)

						Text(bias.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)

						if let evidenceNote = bias.evidenceNote, !evidenceNote.isEmpty {
							NotesSection(list: [evidenceNote], title: "Evidence Note")
								.padding(.top)
						}

						if !bias.counters.isEmpty {
							VStack(alignment: .leading, spacing: 13) {
								Text("Counters")
									.textCase(.uppercase)
									.foregroundStyle(.accent)

								VStack(alignment: .leading, spacing: 4) {
									ForEach(bias.counters, id: \.self) { counter in
										Text("-  \(counter)")
									}
								}
							}
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
						}

						ExamplesSection(list: bias.examples)
							.padding(.top)

						NotesSection(list: bias.limitations)
							.padding(.top)

						LookalikeSection(list: bias.lookalikes)
							.padding(.top)

						RelatedSection(list: bias.related)
							.padding(.top)

						TagSection(list: bias.tags.map { tag in
							CatalogTag(
								id: "biases.\(tag.rawValue)",
								title: tag.title,
								route: .biases(filter: tag)
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
				.navigationTitle(bias.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.richNavigationTitle(height: 40, width: 360) {
					VStack {
						Text(hasScrolled ? bias.name : "")

						Text(hasScrolled ? "Biases" : "")
							.textCase(.uppercase)
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
					.contentTransition(.numericText())
					.animation(.easeInOut(duration: 0.2), value: hasScrolled)
				}
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					ToolbarItem(placement: .topBarTrailing) {
						let reference = CatalogReference(
							id: bias.id,
							name: bias.name,
							category: .biases
						)

						let isBookmarked = bookmarks.contains(reference)

						Button {
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
				Text("Bias not found")

				Button {
					navigation.libraryPath.removeLast()
				} label: {
					Text("Go Back")
				}
			}
		}
	}
}
