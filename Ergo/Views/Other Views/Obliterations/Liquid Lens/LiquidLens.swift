//
//  LiquidLens.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

// Usage: LiquidLensDemo() includes a tappable white-to-glass example.
// Private UIKit API; runtime compatibility is not guaranteed.
//
// Lens-only usage:
//
// ZStack {
//     LinearGradient(colors: [.pink, .orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
//     LiquidLens(isLifted: true)
//         .frame(width: 180, height: 96)
//     Label("Liquid Lens", systemImage: "sparkles")
//         .foregroundStyle(.white)
// }

import Foundation
import SwiftUI

#if canImport(UIKit)
	import ObjectiveC.runtime
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

func clampedLiquidLensDragTranslation(
	_ translation: CGSize,
	horizontalRange: ClosedRange<CGFloat>?,
	verticalRange: ClosedRange<CGFloat>?
) -> CGSize {
	func clampedAxis(_ value: CGFloat, range: ClosedRange<CGFloat>?) -> CGFloat {
		let finiteValue = value.isFinite ? value : 0
		guard let range,
		      range.lowerBound.isFinite,
		      range.upperBound.isFinite
		else {
			return finiteValue
		}

		return min(max(finiteValue, range.lowerBound), range.upperBound)
	}

	return CGSize(
		width: clampedAxis(translation.width, range: horizontalRange),
		height: clampedAxis(translation.height, range: verticalRange)
	)
}

/// Private UIKit lens on supported runtimes; public glass fallback on native macOS.
/// Runtime-inspected on iOS 27.2. Private selectors can change between OS releases.
@MainActor
public struct LiquidLens: View {
	public static let privateLensAvailable: Bool = {
		#if canImport(UIKit)
			NSClassFromString("_UILiquidLensView") != nil
		#else
			false
		#endif
	}()

	/// Nil preserves (or restores) the native default. Spec tuning may affect shared UIKit settings.
	/// Native macOS uses a public glass fallback and ignores lens-specific configuration.
	public struct Configuration {
		#if canImport(UIKit)
			public var style: Int?
			public var liftedContentMode: Int?
			public var warpsContentBelow: Bool?
			public var restingBackgroundColor: UIColor?
			public var restingBorderColor: UIColor?
			public var restingShadowProperties: NSObject?
			public var liftedContainerView: UIView?
			public var liftedContentView: UIView?
			public var overridePunchoutView: UIView?
			/// Initializer-only. Changing this requires a new SwiftUI identity via .id(...).
			public var restingBackgroundView: UIView?
		#endif

		public var lensHangTime: Double?
		public var liftedDisplacement: Double?
		public var unliftedDisplacement: Double?
		public var unliftedBlurRadius: Double?
		public var innerShadowRadius: Double?
		public var innerShadowOpacity: Double?
		public var innerShadowOffsetY: Double?
		public var contentWrapperDisplacement: Double?
		public var liftSpring: NSObject?
		public var unLiftSpring: NSObject?
		public var tryMe: Bool?

		#if canImport(UIKit)
			public init(
				style: Int? = nil,
				liftedContentMode: Int? = nil,
				warpsContentBelow: Bool? = nil,
				restingBackgroundColor: UIColor? = nil,
				restingBorderColor: UIColor? = nil,
				restingShadowProperties: NSObject? = nil,
				liftedContainerView: UIView? = nil,
				liftedContentView: UIView? = nil,
				overridePunchoutView: UIView? = nil,
				restingBackgroundView: UIView? = nil,
				lensHangTime: Double? = nil,
				liftedDisplacement: Double? = nil,
				unliftedDisplacement: Double? = nil,
				unliftedBlurRadius: Double? = nil,
				innerShadowRadius: Double? = nil,
				innerShadowOpacity: Double? = nil,
				innerShadowOffsetY: Double? = nil,
				contentWrapperDisplacement: Double? = nil,
				liftSpring: NSObject? = nil,
				unLiftSpring: NSObject? = nil,
				tryMe: Bool? = nil
			) {
				self.style = style
				self.liftedContentMode = liftedContentMode
				self.warpsContentBelow = warpsContentBelow
				self.restingBackgroundColor = restingBackgroundColor
				self.restingBorderColor = restingBorderColor
				self.restingShadowProperties = restingShadowProperties
				self.liftedContainerView = liftedContainerView
				self.liftedContentView = liftedContentView
				self.overridePunchoutView = overridePunchoutView
				self.restingBackgroundView = restingBackgroundView
				self.lensHangTime = lensHangTime
				self.liftedDisplacement = liftedDisplacement
				self.unliftedDisplacement = unliftedDisplacement
				self.unliftedBlurRadius = unliftedBlurRadius
				self.innerShadowRadius = innerShadowRadius
				self.innerShadowOpacity = innerShadowOpacity
				self.innerShadowOffsetY = innerShadowOffsetY
				self.contentWrapperDisplacement = contentWrapperDisplacement
				self.liftSpring = liftSpring
				self.unLiftSpring = unLiftSpring
				self.tryMe = tryMe
			}
		#else
			public init(
				lensHangTime: Double? = nil,
				liftedDisplacement: Double? = nil,
				unliftedDisplacement: Double? = nil,
				unliftedBlurRadius: Double? = nil,
				innerShadowRadius: Double? = nil,
				innerShadowOpacity: Double? = nil,
				innerShadowOffsetY: Double? = nil,
				contentWrapperDisplacement: Double? = nil,
				liftSpring: NSObject? = nil,
				unLiftSpring: NSObject? = nil,
				tryMe: Bool? = nil
			) {
				self.lensHangTime = lensHangTime
				self.liftedDisplacement = liftedDisplacement
				self.unliftedDisplacement = unliftedDisplacement
				self.unliftedBlurRadius = unliftedBlurRadius
				self.innerShadowRadius = innerShadowRadius
				self.innerShadowOpacity = innerShadowOpacity
				self.innerShadowOffsetY = innerShadowOffsetY
				self.contentWrapperDisplacement = contentWrapperDisplacement
				self.liftSpring = liftSpring
				self.unLiftSpring = unLiftSpring
				self.tryMe = tryMe
			}
		#endif
	}

	public typealias Configure = (RuntimeHandle) -> Void

	public let isLifted: Bool
	public let animated: Bool
	/// Moves the native lens inside its host, driving UIKit’s velocity-based flex interaction.
	public let dragTranslation: CGSize
	/// Limits apply to center displacement; native flex may extend past these bounds.
	public let horizontalDragRange: ClosedRange<CGFloat>?
	/// Limits apply to center displacement; native flex may extend past these bounds.
	public let verticalDragRange: ClosedRange<CGFloat>?
	public let configuration: Configuration
	private let alongsideAnimations: (() -> Void)?
	private let completion: (() -> Void)?
	private let configure: Configure?

	public init(
		isLifted: Bool = false,
		animated: Bool = true,
		dragTranslation: CGSize = .zero,
		horizontalDragRange: ClosedRange<CGFloat>? = nil,
		verticalDragRange: ClosedRange<CGFloat>? = nil,
		configuration: Configuration? = nil,
		alongsideAnimations: (() -> Void)? = nil,
		completion: (() -> Void)? = nil,
		configure: Configure? = nil
	) {
		self.isLifted = isLifted
		self.animated = animated
		self.dragTranslation = dragTranslation
		self.horizontalDragRange = horizontalDragRange
		self.verticalDragRange = verticalDragRange
		self.configuration = configuration ?? Configuration()
		self.alongsideAnimations = alongsideAnimations
		self.completion = completion
		self.configure = configure
	}

	public var body: some View {
		Representable(
			isLifted: isLifted,
			animated: animated,
			dragTranslation: clampedLiquidLensDragTranslation(
				dragTranslation,
				horizontalRange: horizontalDragRange,
				verticalRange: verticalDragRange
			),
			configuration: configuration,
			alongsideAnimations: alongsideAnimations,
			completion: completion,
			configure: configure
		)
		.accessibilityHidden(true)
	}
}
