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

	@State private var showAliases = false

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
					VStack(alignment: .leading) {
						Button {
							if !razor.aliases.isEmpty {
								showAliases = true
							}
						} label: {
							Text(razor.name)
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
									ForEach(razor.aliases, id: \.description) { alt in
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

						Text(razor.summary)
							.lineLimit(10)

						VStack {
							Image(systemName: "quote.opening")
								.frame(maxWidth: .infinity, alignment: .leading)

							Text(razor.lensQuestion)
								.font(.title3)
								.padding(.horizontal, 24)
								.frame(maxWidth: .infinity, alignment: .center)

							Image(systemName: "quote.closing")
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
						.padding(12)
						.frame(maxWidth: .infinity, alignment: .leading)
						.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
						.padding(.vertical, 20)

						Text(razor.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

						examples
							.padding(.top)

						notes
							.padding(.top)

						RelatedSection(list: razor.related)
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
					navigation.libraryPath = [.category(.razors)]
				} label: {
					Text("Go Back")
				}
			}
		}
	}

	@ContentBuilder
	var tags: some View {
		if let razor = catalog.razors.razors.first(where: { $0.id == id }) {
			if !razor.tags.isEmpty {
				VStack(alignment: .leading, spacing: 13) {
					Text("Tags")
						.textCase(.uppercase)
						.foregroundStyle(.secondary)

					VStack(alignment: .leading, spacing: 4) {
						ForEach(razor.tags, id: \.self) { tag in
							NavigationLink(value: LibraryRoute.razors(filter: tag)) {
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
	var notes: some View {
		if let razor = catalog.razors.razors.first(where: { $0.id == id }) {
			VStack(alignment: .leading, spacing: 13) {
				Text("Notes")
					.textCase(.uppercase)
					.foregroundStyle(.accent)
				VStack(alignment: .leading, spacing: 4) {
					ForEach(razor.limitations, id: \.self) { limitation in
						Text("-  \(limitation)")
					}
				}
			}
			.padding(12)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
		}
	}

	@ContentBuilder
	var examples: some View {
		if let razor = catalog.razors.razors.first(where: { $0.id == id }) {
			VStack(alignment: .leading, spacing: 13) {
				Text("Examples")
					.textCase(.uppercase)
					.foregroundStyle(.accent)

				VStack(alignment: .leading, spacing: 4) {
					ForEach(razor.examples, id: \.text) { example in
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
