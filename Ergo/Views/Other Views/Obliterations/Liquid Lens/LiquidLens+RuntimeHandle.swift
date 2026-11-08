//
//  LiquidLens+RuntimeHandle.swift
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

public extension LiquidLens {
	@MainActor
	final class RuntimeHandle {
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

			func attach(to lensView: UIView) {
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
				      let runtimeMethod = unsafe class_getInstanceMethod(type(of: lensView), selector),
				      unsafe method_getNumberOfArguments(runtimeMethod) == 2,
				      unsafe String(cString: method_getTypeEncoding(runtimeMethod)!).hasPrefix("v"),
				      let address = unsafe lensView.method(for: selector)
				else {
					return false
				}
				typealias Function = @convention(c) (AnyObject, Selector) -> Void
				unsafe unsafeBitCast(address, to: Function.self)(lensView, selector)
				return true
			}
		#else
			func attach(to _: NSView) {}

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
}
