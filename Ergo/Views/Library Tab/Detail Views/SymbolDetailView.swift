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

	@State private var hasScrolled = false

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

						NotesSection(list: symbol.englishReadings, title: "English Readings")
							.padding(.top)

						ExamplesSection(list: symbol.examples)
							.padding(.top)

						NotesSection(list: symbol.limitations)
							.padding(.top)

						LookalikeSection(list: symbol.lookalikes)
							.padding(.top)

						RelatedSection(list: symbol.related)
							.padding(.top)

						TagSection(list: symbol.tags.map { tag in
							CatalogTag(
								id: "symbols.\(tag.rawValue)",
								title: tag.title,
								route: .symbols(filter: .tag(tag))
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
				.navigationTitle(symbol.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 150
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.richNavigationTitle(height: 40, width: 360) {
					VStack {
						Text(hasScrolled ? symbol.name : "")

						Text(hasScrolled ? "Symbols" : "")
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
					navigation.libraryPath.removeLast()
				} label: {
					Text("Go Back")
				}
			}
		}
	}

	@ContentBuilder
	var headerButton: some View {
		if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
			Button {
				if !symbol.alternateGlyphs.isEmpty || !symbol.aliases.isEmpty || !symbol.englishReadings.isEmpty {
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
