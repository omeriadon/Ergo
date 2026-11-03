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

private func clampedLiquidLensDragTranslation(
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

#if canImport(UIKit)
	import ObjectiveC.runtime
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

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

	@MainActor
	public final class RuntimeHandle {
		public enum Property: String, CaseIterable {
			case style
			case liftedContentMode
			case warpsContentBelow
			case lifted
			case underlyingLifted = "_lifted"
			case flexInteraction
			case restingBackgroundColor
			case restingBorderColor
			case restingShadowProperties
			case liftedContainerView
			case liftedContentView
			case overridePunchoutView
			case restingBackgroundView
			case liftPortal
			case glass
			case spec
			case belowGlassWarpBackdrop
			case liftedContentPunchout
			case hasCustomRestingBackground
			case restingBackground
			case contentWrapper
			case liftProgress
			case unliftDelayTimer
			case forceUnliftTimerWithoutAnimations
			case groupCompletion
			case lensHangTime = "spec.lensHangTime"
			case liftedDisplacement = "spec.liftedDisplacement"
			case unliftedDisplacement = "spec.unliftedDisplacement"
			case unliftedBlurRadius = "spec.unliftedBlurRadius"
			case innerShadowRadius = "spec.innerShadowRadius"
			case innerShadowOpacity = "spec.innerShadowOpacity"
			case innerShadowOffsetY = "spec.innerShadowOffsetY"
			case contentWrapperDisplacement = "spec.contentWrapperDisplacement"
			case liftSpring = "spec.liftSpring"
			case unLiftSpring = "spec.unLiftSpring"
			case tryMe = "spec.tryMe"
		}

		public enum Method: String, CaseIterable {
			case forceUnliftWithoutAnimations
			case updatePunchoutView
			case updateRestingBackgroundView
		}

		#if canImport(UIKit)
			private weak var lensView: UIView?

			/// UIKit-owned lens and subviews, for advanced inspection. Do not replace its plumbing.
			public var view: UIView? {
				lensView
			}

			/// Displacement effects created lazily by UIKit after layout/lifting.
			public var displacementEffects: [NSObject] {
				guard let lensView else { return [] }
				var effects: [NSObject] = []
				func visit(_ view: UIView) {
					if view.layer.responds(to: NSSelectorFromString("effect")),
					   let effect = view.layer.value(forKey: "effect") as? NSObject,
					   NSStringFromClass(type(of: effect)) == "CASDFGlassDisplacementEffect"
					{
						effects.append(effect)
					}
					view.subviews.forEach(visit)
				}
				visit(lensView)
				return effects
			}

			/// Checked access for nested portal, SDF, and spring settings.
			@discardableResult
			public func setValue(_ value: Any?, forKeyPath keyPath: String, on object: NSObject) -> Bool {
				Runtime.setValue(value, keyPath: keyPath, on: object)
			}

			fileprivate func attach(to lensView: UIView) {
				self.lensView = lensView
			}

			public func value(for property: Property) -> Any? {
				guard let lensView else {
					return nil
				}
				return Runtime.value(for: property, on: lensView)
			}

			@discardableResult
			public func setValue(_ value: Any?, for property: Property) -> Bool {
				guard let lensView else {
					return false
				}
				return Runtime.setValue(value, for: property, on: lensView)
			}

			@discardableResult
			public func call(_ method: Method) -> Bool {
				guard let lensView,
				      let selector = Runtime.selector(for: method),
				      lensView.responds(to: selector),
				      let runtimeMethod = class_getInstanceMethod(type(of: lensView), selector),
				      method_getNumberOfArguments(runtimeMethod) == 2,
				      String(cString: method_getTypeEncoding(runtimeMethod)!).hasPrefix("v"),
				      let address = lensView.method(for: selector)
				else {
					return false
				}
				typealias Function = @convention(c) (AnyObject, Selector) -> Void
				unsafeBitCast(address, to: Function.self)(lensView, selector)
				return true
			}
		#else
			fileprivate func attach(to _: NSView) {}

			public func value(for _: Property) -> Any? {
				nil
			}

			@discardableResult
			public func setValue(_: Any?, for _: Property) -> Bool {
				false
			}

			@discardableResult
			public func call(_: Method) -> Bool {
				false
			}
		#endif
	}

	#if canImport(UIKit)
		private struct Representable: UIViewRepresentable {
			let isLifted: Bool
			let animated: Bool
			let dragTranslation: CGSize
			let configuration: Configuration
			let alongsideAnimations: (() -> Void)?
			let completion: (() -> Void)?
			let configure: Configure?

			func makeCoordinator() -> Coordinator {
				Coordinator()
			}

			func makeUIView(context: Context) -> UIView {
				let view = Runtime.makeLens(restingBackgroundView: configuration.restingBackgroundView)
					?? UIView(frame: .zero)
				view.isUserInteractionEnabled = true
				view.isAccessibilityElement = false
				view.accessibilityElementsHidden = true
				view.backgroundColor = .clear
				context.coordinator.handle.attach(to: view)
				return LensHostView(lens: view)
			}

			func updateUIView(_ view: UIView, context: Context) {
				guard let host = view as? LensHostView else { return }
				let lens = host.lens
				Runtime.apply(configuration, to: lens, defaults: &context.coordinator.defaults)
				configure?(context.coordinator.handle)
				host.requestedLift = isLifted
				let shouldAnimate = animated && !context.environment.accessibilityReduceMotion
				host.applyLift = { [weak lens] in
					guard let lens else { return }
					Runtime.setLifted(
						isLifted,
						animated: shouldAnimate,
						alongsideAnimations: alongsideAnimations,
						completion: completion,
						on: lens
					)
				}
				host.applyIfNeeded()
				host.updateDragTranslation(dragTranslation, animated: shouldAnimate)
			}

			final class Coordinator {
				let handle = RuntimeHandle()
				var defaults: [String: Any] = [:]
			}
		}

		private final class LensHostView: UIView {
			let lens: UIView
			var requestedLift: Bool?
			private var appliedLift: Bool?
			var applyLift: (() -> Void)?
			private var dragTranslation: CGSize = .zero

			init(lens: UIView) {
				self.lens = lens
				super.init(frame: .zero)

				isUserInteractionEnabled = true
				addSubview(lens)

				let selector = NSSelectorFromString("setLiftedContainerView:")

				if lens.responds(to: selector) {
					_ = lens.perform(selector, with: self)
				}
			}

			@available(*, unavailable)
			required init?(coder _: NSCoder) {
				fatalError("init(coder:) is unavailable")
			}

			override func layoutSubviews() {
				super.layoutSubviews()
				if lens.bounds.size != bounds.size {
					lens.bounds = CGRect(origin: .zero, size: bounds.size)
				}
				if lens.center != translatedCenter {
					lens.center = translatedCenter
				}
			}

			private var translatedCenter: CGPoint {
				CGPoint(
					x: bounds.midX + dragTranslation.width,
					y: bounds.midY + dragTranslation.height
				)
			}

			func updateDragTranslation(_ translation: CGSize, animated: Bool) {
				guard dragTranslation != translation else { return }
				dragTranslation = translation
				let center = translatedCenter
				if animated, translation == .zero {
					UIView.animate(springDuration: 0.35) {
						self.lens.center = center
					}
				} else {
					lens.center = center
				}
			}

			override func didMoveToWindow() {
				super.didMoveToWindow()
				if window == nil {
					appliedLift = nil
				}
				// UIKit delivers the lens's own didMoveToWindow after its host's callback.
				DispatchQueue.main.async { [weak self] in
					self?.applyIfNeeded()
				}
			}

			func applyIfNeeded() {
				guard window != nil, let requestedLift, requestedLift != appliedLift else { return }
				// Layout before UIKit constructs its displacement and portal geometry.
				layoutIfNeeded()
				appliedLift = requestedLift
				applyLift?()
			}
		}
	#else
		private struct Representable: NSViewRepresentable {
			let isLifted: Bool
			let animated: Bool
			let dragTranslation: CGSize
			let configuration: Configuration
			let alongsideAnimations: (() -> Void)?
			let completion: (() -> Void)?
			let configure: Configure?

			func makeCoordinator() -> Coordinator {
				Coordinator()
			}

			func makeNSView(context: Context) -> NSView {
				let view: NSView
				if #available(macOS 26.0, *) {
					view = NSGlassEffectView()
				} else {
					let effectView = NSVisualEffectView()
					effectView.material = .hudWindow
					effectView.blendingMode = .behindWindow
					view = effectView
				}
				view.wantsLayer = true
				view.layer?.cornerRadius = 18
				view.layer?.masksToBounds = true
				view.setAccessibilityElement(false)
				context.coordinator.handle.attach(to: view)
				configure?(context.coordinator.handle)
				return view
			}

			func updateNSView(_ view: NSView, context: Context) {
				view.needsLayout = true
				configure?(context.coordinator.handle)
			}

			final class Coordinator {
				let handle = RuntimeHandle()
			}
		}
	#endif
}

#if canImport(UIKit)
	@MainActor
	private enum Runtime {
		private static let lensClassName = "_UILiquidLensView"

		static func makeLens(restingBackgroundView: UIView?) -> UIView? {
			guard let lensClass = NSClassFromString(lensClassName),
			      lensClass is UIView.Type,
			      let allocMethod = class_getClassMethod(lensClass, NSSelectorFromString("alloc")),
			      let initializer = class_getInstanceMethod(lensClass, NSSelectorFromString("initWithRestingBackground:")),
			      signature(initializer, returns: "@", arguments: ["@"])
			else {
				return nil
			}
			typealias Alloc = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
			typealias Initializer = @convention(c) (UnsafeMutableRawPointer, Selector, UIView?) -> Unmanaged<AnyObject>?
			// Keep alloc's +1 unmanaged until init returns it. Consume that ownership exactly once.
			let allocated = unsafeBitCast(method_getImplementation(allocMethod), to: Alloc.self)(
				lensClass, NSSelectorFromString("alloc")
			)
			let initialized = unsafeBitCast(method_getImplementation(initializer), to: Initializer.self)(
				allocated.toOpaque(), NSSelectorFromString("initWithRestingBackground:"), restingBackgroundView
			)
			return initialized?.takeRetainedValue() as? UIView
		}

		static func apply(_ c: LiquidLens.Configuration, to view: UIView, defaults: inout [String: Any]) {
			// PTSettings may be shared by UIKit. Tuning is opt-in and can affect other lenses.
			let values: [(String, Any?)] = [
				("style", c.style),
				("liftedContentMode", c.liftedContentMode),
				("warpsContentBelow", c.warpsContentBelow),
				("restingBackgroundColor", c.restingBackgroundColor),
				("restingBorderColor", c.restingBorderColor),
				("restingShadowProperties", c.restingShadowProperties),
				("liftedContainerView", c.liftedContainerView),
				("liftedContentView", c.liftedContentView),
				("overridePunchoutView", c.overridePunchoutView),
				("spec.lensHangTime", c.lensHangTime),
				("spec.liftedDisplacement", c.liftedDisplacement),
				("spec.unliftedDisplacement", c.unliftedDisplacement),
				("spec.unliftedBlurRadius", c.unliftedBlurRadius),
				("spec.innerShadowRadius", c.innerShadowRadius),
				("spec.innerShadowOpacity", c.innerShadowOpacity),
				("spec.innerShadowOffsetY", c.innerShadowOffsetY),
				("spec.contentWrapperDisplacement", c.contentWrapperDisplacement),
				("spec.liftSpring", c.liftSpring),
				("spec.unLiftSpring", c.unLiftSpring),
				("spec.tryMe", c.tryMe),
			]
			for (key, value) in values {
				if let value {
					if let target = target(keyPath: key, on: view) {
						if let saved = defaults[key] as? (NSObject, String, Any), saved.0 !== target.object {
							_ = setValue(saved.2 is NSNull ? nil : saved.2, keyPath: saved.1, on: saved.0)
							defaults.removeValue(forKey: key)
						}
						if defaults[key] == nil {
							defaults[key] = (target.object, target.key, target.object.value(forKey: target.key) ?? NSNull())
						}
					}
					if let target = target(keyPath: key, on: view),
					   let existing = target.object.value(forKey: target.key) as? NSObject,
					   let incoming = value as? NSObject,
					   existing.isEqual(incoming)
					{
						continue
					}
					_ = setValue(value, keyPath: key, on: view)
				} else if let original = defaults.removeValue(forKey: key) as? (NSObject, String, Any) {
					_ = setValue(original.2 is NSNull ? nil : original.2, keyPath: original.1, on: original.0)
				}
			}
		}

		private static func signature(_ method: Method, returns result: String, arguments: [String]) -> Bool {
			guard method_getNumberOfArguments(method) == arguments.count + 2 else { return false }
			let returnType = method_copyReturnType(method)
			defer { free(returnType) }
			guard String(cString: returnType) == result else { return false }
			for (index, expected) in arguments.enumerated() {
				guard let type = method_copyArgumentType(method, UInt32(index + 2)) else { return false }
				defer { free(type) }
				guard String(cString: type) == expected else { return false }
			}
			return true
		}

		static func setLifted(
			_ lifted: Bool,
			animated: Bool,
			alongsideAnimations: (() -> Void)?,
			completion: (() -> Void)?,
			on view: UIView
		) {
			let selector = NSSelectorFromString("setLifted:animated:alongsideAnimations:completion:")
			guard let method = class_getInstanceMethod(type(of: view), selector),
			      signature(method, returns: "v", arguments: ["B", "B", "@?", "@?"]),
			      let address = view.method(for: selector)
			else {
				return
			}
			typealias Function = @convention(c) (AnyObject, Selector, Bool, Bool, @escaping () -> Void, (() -> Void)?) -> Void
			unsafeBitCast(address, to: Function.self)(
				view,
				selector,
				lifted,
				animated,
				alongsideAnimations ?? {},
				completion
			)
		}

		static func value(for property: LiquidLens.RuntimeHandle.Property, on view: UIView) -> Any? {
			guard let target = target(keyPath: property.rawValue, on: view) else { return nil }
			return target.object.value(forKey: target.key)
		}

		@discardableResult
		static func setValue(_ value: Any?, for property: LiquidLens.RuntimeHandle.Property, on view: UIView) -> Bool {
			setValue(value, keyPath: property.rawValue, on: view)
		}

		private static func target(keyPath: String, on root: NSObject) -> (object: NSObject, key: String)? {
			let parts = keyPath.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
			guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
			var object = root
			for (index, key) in parts.enumerated() {
				let getter = NSSelectorFromString(key)
				guard let method = class_getInstanceMethod(type(of: object), getter),
				      method_getNumberOfArguments(method) == 2 else { return nil }
				if index == parts.count - 1 {
					return (object, key)
				}
				guard signature(method, returns: "@", arguments: []),
				      let next = object.value(forKey: key) as? NSObject else { return nil }
				object = next
			}
			return nil
		}

		@discardableResult
		static func setValue(_ value: Any?, keyPath: String, on root: NSObject) -> Bool {
			guard let target = target(keyPath: keyPath, on: root) else { return false }
			let setter = NSSelectorFromString("set\(target.key.prefix(1).uppercased())\(target.key.dropFirst()):")
			guard let method = class_getInstanceMethod(type(of: target.object), setter),
			      method_getNumberOfArguments(method) == 3,
			      let argument = method_copyArgumentType(method, 2) else { return false }
			defer { free(argument) }
			switch String(cString: argument) {
				case "@":
					// Check the declared class where Objective-C metadata supplies one.
					if let value = value as? NSObject,
					   let property = class_getProperty(type(of: target.object), target.key),
					   let attributes = property_getAttributes(property)
					{
						let type = String(cString: attributes)
						if type.hasPrefix("T@\""),
						   let end = type.dropFirst(3).firstIndex(of: "\""),
						   let expected = NSClassFromString(String(type[type.index(type.startIndex, offsetBy: 3) ..< end])),
						   !value.isKind(of: expected)
						{
							return false
						}
					}
				case "B", "q", "Q", "i", "I", "f", "d":
					guard value is NSNumber else { return false }
				default:
					return false
			}
			target.object.setValue(value, forKey: target.key)
			return true
		}

		fileprivate static func selector(for method: LiquidLens.RuntimeHandle.Method) -> Selector? {
			NSSelectorFromString(method.rawValue)
		}
	}
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
