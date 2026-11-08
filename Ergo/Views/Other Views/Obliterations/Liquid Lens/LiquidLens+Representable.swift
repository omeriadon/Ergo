//
//  LiquidLens+Representable.swift
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

extension LiquidLens {
	#if canImport(UIKit)
		struct Representable: UIViewRepresentable {
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

		final class LensHostView: UIView {
			let lens: UIView
			var requestedLift: Bool?
			var appliedLift: Bool?
			var applyLift: (() -> Void)?
			var dragTranslation: CGSize = .zero

			init(lens: UIView) {
				self.lens = lens
				super.init(frame: .zero)

				isUserInteractionEnabled = true
				addSubview(lens)

				let selector = NSSelectorFromString("setLiftedContainerView:")

				if lens.responds(to: selector) {
					_ = unsafe lens.perform(selector, with: self)
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

			var translatedCenter: CGPoint {
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
		struct Representable: NSViewRepresentable {
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
