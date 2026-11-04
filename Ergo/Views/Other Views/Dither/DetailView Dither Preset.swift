//
//  Dither Preset.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Foundation

public var detailViewConf: DitherConfiguration {
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

	c.cursorInteractionEnabled = false
	c.cursorRadius = 0.3
	c.cursorStrength = 0.7
	c.cursorResponse = 0
	c.cursorTrailDuration = 0
	c.cursorFadeDuration = 0.4
	c.cursorWarp = 0.15

	return c
}
