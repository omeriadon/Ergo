//
//  SymbolDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import SwiftUI

struct SymbolDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var showAlternateGlyphs = false

	@Default(.bookmarks) var bookmarks

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var conf = detailViewConf
				conf.palette = [
					Color.orange.toSIMD3,
					Color.orange.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
				ScrollView {
					VStack(alignment: .leading) {
						HStack(alignment: .top) {
							headerButton

							Spacer()

							HStack {
								Text("Group:")
									.font(.caption)
									.foregroundStyle(.secondary)
									.textCase(.uppercase)

								NavigationLink(value: LibraryRoute.symbols(filter: .group(symbol.group))) {
									HStack(spacing: 2) {
										Text(symbol.group.rawValue.capitalized)
										Image(systemName: "chevron.right")
											.imageScale(.small)
									}
								}
							}
							.padding(.top, 20)
						}

						Text(symbol.name)
							.font(.largeTitle.bold())

						Spacer()
							.frame(height: 10)

						Text(symbol.summary)
							.lineLimit(10)

						Text(symbol.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)

						examples
							.padding(.top)

						notes
							.padding(.top)

						lookalikes
							.padding(.top)

						related
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
				.navigationTitle(symbol.name.capitalized)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					ToolbarItem(placement: .topBarTrailing) {
						let reference = CatalogReference(
							id: symbol.id,
							name: symbol.name,
							category: .symbols
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
				Text("Symbol not found")

				Button {
					navigation.libraryPath = [.category(.symbols)]
				} label: {
					Text("Go Back")
				}
			}
		}
	}

	@ContentBuilder
	var tags: some View {
		if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
			if !symbol.tags.isEmpty {
				VStack(alignment: .leading, spacing: 13) {
					Text("Tags")
						.textCase(.uppercase)
						.foregroundStyle(.accent)

					VStack(alignment: .leading, spacing: 4) {
						ForEach(symbol.tags, id: \.self) { tag in
							NavigationLink(value: LibraryRoute.symbols(filter: .tag(tag))) {
								HStack {
									Image(systemName: "tag")
										.imageScale(.small)

									Text(tag.title)
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
		if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
			VStack(alignment: .leading, spacing: 13) {
				Text("Examples")
					.textCase(.uppercase)
					.foregroundStyle(.accent)

				VStack(alignment: .leading, spacing: 4) {
					ForEach(symbol.examples, id: \.text) { example in
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
		if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
			VStack(alignment: .leading, spacing: 13) {
				Text("Notes")
					.textCase(.uppercase)
					.foregroundStyle(.accent)
				VStack(alignment: .leading, spacing: 4) {
					ForEach(symbol.limitations, id: \.self) { limitation in
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
	var lookalikes: some View {
		if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
			if !symbol.lookalikes.isEmpty {
				VStack(alignment: .leading, spacing: 13) {
					Text("Not To Be Confused With:")
						.textCase(.uppercase)
						.foregroundStyle(.accent)

					VStack(alignment: .leading, spacing: 4) {
						ForEach(symbol.lookalikes, id: \.target.id) { lookalike in
							let target = lookalike.target
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

	@ContentBuilder
	var related: some View {
		if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
			if !symbol.related.isEmpty {
				VStack(alignment: .leading, spacing: 13) {
					Text("Related")
						.textCase(.uppercase)
						.foregroundStyle(.accent)

					VStack(alignment: .leading, spacing: 4) {
						ForEach(symbol.related, id: \.id) { target in
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

	@ContentBuilder
	var headerButton: some View {
		if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
			Button {
				if !symbol.alternateGlyphs.isEmpty || !symbol.aliases.isEmpty {
					showAlternateGlyphs = true
				}
			} label: {
				Text(symbol.glyph)
					.font(.largeTitle.scaled(by: 2.4))
					.popover(isPresented: $showAlternateGlyphs) {
						VStack(alignment: .leading, spacing: 20) {
							if !symbol.alternateGlyphs.isEmpty {
								VStack(alignment: .leading) {
									Text("Alternate Glyphs")
										.font(.caption)
										.foregroundStyle(.secondary)
										.textCase(.uppercase)

									HStack(spacing: 45) {
										ForEach(symbol.alternateGlyphs, id: \.description) { alt in
											Text(alt)
										}
									}
									.font(.system(.largeTitle, design: .monospaced))
									.monospaced()
								}
							}

							if !symbol.aliases.isEmpty {
								VStack(alignment: .leading) {
									Text("Aliases")
										.font(.caption)
										.foregroundStyle(.secondary)
										.textCase(.uppercase)

									HStack(spacing: 45) {
										ForEach(symbol.aliases, id: \.description) { alt in
											Text(alt)
												.lineLimit(3)
												.minimumScaleFactor(0.1)
										}
									}
									.font(.system(.title, design: .monospaced))
									.monospaced()
								}
							}

							if !symbol.englishReadings.isEmpty {
								VStack(alignment: .leading) {
									Text("English Readings")
										.font(.caption)
										.foregroundStyle(.secondary)
										.textCase(.uppercase)

									VStack(alignment: .leading, spacing: 8) {
										ForEach(symbol.englishReadings, id: \.description) { alt in
											Text("- \(alt)")
										}
									}
									.font(.system(.title3, design: .monospaced))
									.monospaced()
								}
							}
						}
						.padding()
						.presentationCompactAdaptation(.popover)
					}
			}
		}
	}
}
