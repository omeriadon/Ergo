//
//  SymbolDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct SymbolDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var showAlternateGlyphs = false

	@State private var hasScrolled = false
	@State private var isOpening = true

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var conf = detailViewConf
				conf.palette = [
					LibraryContent.symbols.themeColor.toSIMD3,
					LibraryContent.symbols.themeColor.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
				ScrollView {
					LazyVStack(alignment: .leading) {
						HStack(alignment: .top) {
							SymbolGlyphButton(symbol: symbol, showsDetails: $showAlternateGlyphs)

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
							.textSelection(.enabled)
							.lineLimit(10)

						Text(symbol.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
							.bounceOnAppear(after: 1)

						ExamplesSection(list: symbol.examples)
							.padding(.top)
							.bounceOnAppear(after: 3)

						NotesSection(list: symbol.limitations)
							.padding(.top)
							.bounceOnAppear(after: 4)

						LookalikeSection(list: symbol.lookalikes)
							.padding(.top)
							.bounceOnAppear(after: 5)

						RelatedSection(list: symbol.related)
							.padding(.top)
							.bounceOnAppear(after: 6)

						TagSection(list: symbol.tags.map { tag in
							CatalogTag(
								id: "symbols.\(tag.rawValue)",
								title: tag.title,
								route: .symbols(filter: .tag(tag))
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
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(symbol.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 150
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(symbol.name, category: "Symbols", hasScrolled: hasScrolled)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					LibraryDetailMenu(reference: CatalogReference(
						id: symbol.id,
						name: symbol.name,
						category: .symbols
					))
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
}

/// The symbol's glyph, big, which opens its other glyphs, aliases and readings
struct SymbolGlyphButton: View {
	let symbol: LogicSymbol
	@Binding var showsDetails: Bool

	var body: some View {
		Button {
			if !symbol.alternateGlyphs.isEmpty || !symbol.aliases.isEmpty || !symbol.englishReadings.isEmpty {
				showsDetails = true
			}
		} label: {
			Text(symbol.glyph)
				.font(.largeTitle.scaled(by: 2.4))
				.popover(isPresented: $showsDetails) {
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
