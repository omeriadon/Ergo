//
//  View+.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import SwiftUI

#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

// MARK: - conditionalButtonStyle

extension View {
	@ViewBuilder
	func conditionalButtonStyle(_ prominent: Bool) -> some View {
		if prominent {
			buttonStyle(.glassProminent)
		} else {
			buttonStyle(.automatic)
		}
	}
}

// MARK: - toSIMD3

extension Color {
	var toSIMD3: SIMD3<Float> {
		#if os(macOS)
			guard let rgb = NSColor(self).usingColorSpace(.sRGB) else {
				return .zero
			}

			return SIMD3(
				Float(rgb.redComponent),
				Float(rgb.greenComponent),
				Float(rgb.blueComponent)
			)
		#else
			var red: CGFloat = 0
			var green: CGFloat = 0
			var blue: CGFloat = 0
			var alpha: CGFloat = 0

			guard UIColor(self).getRed(
				&red,
				green: &green,
				blue: &blue,
				alpha: &alpha
			) else {
				return .zero
			}

			return SIMD3(
				Float(red),
				Float(green),
				Float(blue)
			)
		#endif
	}
}
