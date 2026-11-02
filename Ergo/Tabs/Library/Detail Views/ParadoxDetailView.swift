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

	@State private var showAliases = false

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
						Button {
							if !paradox.aliases.isEmpty {
								showAliases = true
							}
						} label: {
							Text(paradox.name)
								.foregroundStyle(.white)
								.font(.largeTitle.bold())
						}
						.popover(isPresented: $showAliases) {
							VStack(alignment: .leading) {
								Text("Aliases")
									.font(.caption)
									.foregroundStyle(.secondary)
									.textCase(.uppercase)

								HStack(spacing: 45) {
									ForEach(paradox.aliases, id: \.description) { alt in
										Text(alt)
											.lineLimit(3)
											.minimumScaleFactor(0.1)
									}
								}
								.font(.system(.title2, design: .monospaced))
								.monospaced()
							}
							.padding()
							.foregroundStyle(.accent)
							.presentationCompactAdaptation(.popover)
						}

						Spacer()
							.frame(height: 10)

						Text(paradox.summary)
							.lineLimit(10)

						Text(paradox.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

						examples
							.padding(.top)

						RelatedSection(list: paradox.related)
							.padding(.top)

						tags
							.padding(.top)

						Spacer()
							.frame(height: 40)
					}
					.padding(.horizontal)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(paradox.name.capitalized)
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
					navigation.libraryPath = [.category(.paradoxes)]
				} label: {
					Text("Go Back")
				}
			}
		}
	}

	@ContentBuilder
	var tags: some View {
		if let paradox = catalog.paradoxes.paradoxes.first(where: { $0.id == id }) {
			if !paradox.tags.isEmpty {
				VStack(alignment: .leading, spacing: 13) {
					Text("Tags")
						.textCase(.uppercase)
						.foregroundStyle(.secondary)

					VStack(alignment: .leading, spacing: 4) {
						ForEach(paradox.tags, id: \.self) { tag in
							NavigationLink(value: LibraryRoute.paradoxes(filter: tag)) {
								HStack {
									Image(systemName: "tag")
										.imageScale(.small)

									Text(tag.rawValue.capitalized)
									Spacer()
									Image(systemName: "chevron.right")
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

	@ContentBuilder
	var examples: some View {
		if let paradox = catalog.paradoxes.paradoxes.first(where: { $0.id == id }) {
			VStack(alignment: .leading, spacing: 13) {
				Text("Examples")
					.textCase(.uppercase)
					.foregroundStyle(.accent)

				VStack(alignment: .leading, spacing: 4) {
					ForEach(paradox.examples, id: \.text) { example in
						Text("-  \(example.text)")
						if let note = example.note {
							Text("-  \(note)")
								.padding(.leading, 30)
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
