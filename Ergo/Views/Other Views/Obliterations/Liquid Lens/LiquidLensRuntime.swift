//
//  LiquidLensRuntime.swift
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

#if canImport(UIKit)
	@MainActor
	enum Runtime {
		static let lensClassName = "_UILiquidLensView"

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

		static func signature(_ method: Method, returns result: String, arguments: [String]) -> Bool {
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

		static func target(keyPath: String, on root: NSObject) -> (object: NSObject, key: String)? {
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

		static func selector(for method: LiquidLens.RuntimeHandle.Method) -> Selector? {
			NSSelectorFromString(method.rawValue)
		}
	}
#endif
