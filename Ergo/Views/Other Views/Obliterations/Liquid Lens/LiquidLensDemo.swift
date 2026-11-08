//
//  LiquidLensDemo.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
	import ObjectiveC.runtime
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

/// Drop `LiquidLensDemo()` into a SwiftUI preview or window to try the transition.
@MainActor
public struct LiquidLensDemo: View {
	@State private var isLifted = false

	public init() {}

	private var configuration: LiquidLens.Configuration {
		#if canImport(UIKit)
			.init(warpsContentBelow: true, restingBackgroundColor: .white)
		#else
			.init()
		#endif
	}

	public var body: some View {
		ZStack {
			LinearGradient(
				colors: [.indigo, .pink, .orange],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()

			VStack(spacing: 24) {
				Button {
					isLifted.toggle()
				} label: {
					Label("Toggle lens", systemImage: "circle.lefthalf.filled")
						.labelStyle(.iconOnly)
						.font(.system(size: 28, weight: .semibold))
						.foregroundStyle(isLifted ? .white : .black)
						.frame(width: 88, height: 88)
						.background {
							LiquidLens(isLifted: isLifted, configuration: configuration)
						}
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Toggle liquid lens")
				.accessibilityValue(isLifted ? "Lifted" : "Resting")
				.accessibilityIdentifier("liquidLens.toggle")

				Text(LiquidLens.privateLensAvailable ? "Tap to switch between white and liquid glass" : "Native macOS glass fallback")
					.font(.callout)
					.foregroundStyle(.white)
					.multilineTextAlignment(.center)
			}
			.padding()
		}
	}
}
