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

	@State private var showAliases = false

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
						Button {
							if !bias.aliases.isEmpty {
								showAliases = true
							}
						} label: {
							Text(bias.name)
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
									ForEach(bias.aliases, id: \.description) { alt in
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

						Text(bias.summary)
							.lineLimit(10)

						Text(bias.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)

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

						examples
							.padding(.top)

						notes
							.padding(.top)

						LookalikeSection(list: bias.lookalikes)
							.padding(.top)

						RelatedSection(list: bias.related)
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
				.navigationTitle(bias.name.capitalized)
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
					navigation.libraryPath = [.category(.biases)]
				} label: {
					Text("Go Back")
				}
			}
		}
	}

	@ContentBuilder
	var tags: some View {
		if let bias = catalog.biases.biases.first(where: { $0.id == id }) {
			if !bias.tags.isEmpty {
				VStack(alignment: .leading, spacing: 13) {
					Text("Tags")
						.textCase(.uppercase)
						.foregroundStyle(.accent)

					VStack(alignment: .leading, spacing: 4) {
						ForEach(bias.tags, id: \.self) { tag in
							NavigationLink(value: LibraryRoute.biases(filter: tag)) {
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
		if let bias = catalog.biases.biases.first(where: { $0.id == id }) {
			VStack(alignment: .leading, spacing: 13) {
				Text("Examples")
					.textCase(.uppercase)
					.foregroundStyle(.accent)

				VStack(alignment: .leading, spacing: 4) {
					ForEach(bias.examples, id: \.text) { example in
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

	@ContentBuilder
	var notes: some View {
		if let bias = catalog.biases.biases.first(where: { $0.id == id }) {
			VStack(alignment: .leading, spacing: 13) {
				Text("Notes")
					.textCase(.uppercase)
					.foregroundStyle(.accent)
				VStack(alignment: .leading, spacing: 4) {
					ForEach(bias.limitations, id: \.self) { limitation in
						Text("-  \(limitation)")
					}
				}
			}
			.padding(12)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
		}
	}
}
