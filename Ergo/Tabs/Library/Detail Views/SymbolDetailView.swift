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

	var body: some View {
		ZStack {
			DitherView(configuration: configuration)
				.ignoresSafeArea()

			if let symbol = catalog.logicSymbols.symbols.first(where: { $0.id == id }) {
				ScrollView {
					VStack(alignment: .leading) {
						HStack(alignment: .top) {
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
														}
													}
													.font(.system(.title, design: .monospaced))
													.monospaced()
												}
											}
										}
										.padding()
										.presentationCompactAdaptation(.popover)
									}
							}

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
							.font(.largeTitle)

						Spacer()
							.frame(height: 10)

						Text(symbol.summary)
							.lineLimit(10)
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
						Button {} label: {
							Label("Bookmark", systemImage: "bookmark")
						}
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

	private var configuration: DitherConfiguration {
		var c = DitherConfiguration()

		// Wave
		c.waveSpeed = 0.001
		c.waveDirection = 135
		c.waveFrequency = 3
		c.waveAmplitude = 0.3
		c.scale = 1
		c.contrast = 1
		c.brightness = 0

		// Animation
		c.disableAnimation = false
		c.intro = false

		// Cells and dithering
		c.pixelSize = 5
		c.colorNum = 10
		c.ditherMode = 0
		c.ditherStrength = 1
		c.gap = 0.2
		c.cornerRadius = 0.2
		c.joinAdjacentSquares = false

		// Colors
		c.waveColor = SIMD3<Float>(0, 0, 0)
		c.backgroundColor = SIMD3<Float>(0, 0, 0)

		c.palette = [
			SIMD3<Float>(122 / 255.0, 82 / 255.0, 48 / 255.0), // #7A5230
			SIMD3<Float>(201 / 255.0, 160 / 255.0, 122 / 255.0), // #C9A07A
		]

		c.backgroundStyle = "custom"
		c.colorPlacement = "squares"
		c.squareStyle = "white"
		c.useThemeColors = false

		// Composition
		c.transparent = false
		c.opacity = 0.7
		c.topBlur = false

		// Requires additional pointer/touch handling to have an effect.
		c.cursorInteractionEnabled = true
		c.cursorRadius = 0.3
		c.cursorStrength = 0.7
		c.cursorResponse = 0
		c.cursorTrailDuration = 0
		c.cursorFadeDuration = 0.4
		c.cursorWarp = 0.15

		return c
	}
}
