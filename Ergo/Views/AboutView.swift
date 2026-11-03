//
//  AboutView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct AboutView: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		NavigationStack {
			ZStack {
				DitherView(configuration: configuration)
					.ignoresSafeArea()

				VStack {
					Spacer()

					VStack(spacing: 0) {
						ErgoIcon(size: 240)

						VStack(spacing: 16) {
							Text("Ergo")
								.font(.largeTitle)
								.bold()

							HStack(spacing: 0) {
								Text("v")
								Text(Bundle.main.appVersion)
								Text(" (")
								Text(Bundle.main.buildNumber)
								Text(")")
							}
							.monospaced()
							.fontDesign(.monospaced)
						}
					}
					.padding(.bottom)
					.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

					Spacer()

					HStack(spacing: 0) {
						Text("made by Adon with ")

						Image(systemName: "heart.fill")
							.foregroundStyle(.red.gradient)
							.symbolEffect(.bounce)
					}
				}
			}
			.fontDesign(.rounded)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .close) {
						navigation.dismissSheet()
					}
				}
			}
		}
		.interactiveDismissDisabled()
	}

	private var configuration: DitherConfiguration {
		var c = DitherConfiguration()

		// Wave
		c.waveSpeed = 0.05
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
		c.colorNum = 4
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
		c.opacity = 1
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

#Preview {
	AboutView()
		.environment(NavigationManager())
}
