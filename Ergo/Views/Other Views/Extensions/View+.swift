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

			guard unsafe UIColor(self).getRed(
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

extension EnvironmentValues {
	/// True while a detail view is opening. Sections first built after this are ones the user scrolled to, so they don't bounce.
	@Entry var isOpeningDetail = false
}

struct BounceOnAppearModifier: ViewModifier {
	let index: Int

	@Environment(\.isOpeningDetail) private var isOpening

	///	@State private var scale: CGFloat = 0.8
	@State private var opacity = 0.0

	func body(content: Content) -> some View {
		let calculatedDelay = 0.1 + (Double(max(0, index - 1)) * 0.1)

		return content
//			.scaleEffect(isOpening ? scale : 1)
			.opacity(isOpening ? opacity : 1)
			.onAppear {
				guard isOpening else { return }

//				withAnimation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0).delay(calculatedDelay)) {
//					scale = 1.0
//				}
				withAnimation(.easeInOut.delay(calculatedDelay)) {
					opacity = 1
				}
			}
	}
}

extension View {
	func bounceOnAppear(after index: Int) -> some View {
		modifier(BounceOnAppearModifier(index: index))
	}
}
