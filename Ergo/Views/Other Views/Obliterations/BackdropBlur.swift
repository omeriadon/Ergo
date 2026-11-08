//
//  BackdropBlur.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import OSLog
import SwiftUI
import UIKit

struct BackdropBlur: View {
	var radius: CGFloat = 10
	/// The edge the blur fades out towards. `nil` blurs evenly.
	var fade: Edge?

	var body: some View {
		if BackdropBlurFilter.isAvailable(variable: fade != nil) {
			BackdropBlurRepresentable(radius: radius, fade: fade)
		} else {
			Rectangle().fill(.ultraThinMaterial)
		}
	}
}

private struct BackdropBlurRepresentable: UIViewRepresentable {
	var radius: CGFloat
	var fade: Edge?

	func makeUIView(context _: Context) -> BackdropBlurUIView {
		BackdropBlurUIView(radius: radius, fade: fade)
	}

	func updateUIView(_ view: BackdropBlurUIView, context _: Context) {
		view.update(radius: radius, fade: fade)
	}
}

enum BackdropBlurFilter {
	private static let log = Logger(subsystem: "Ergo", category: "BackdropBlur")
	private static let className = ["CA", "Filter"].joined()
	private static let layerClassName = ["CA", "Backdrop", "Layer"].joined()
	private static let factory = NSSelectorFromString("filterWithType:")

	/// Probes once per kind, so a broken OS is detected before any view is made.
	private static let plainAvailable = probe(fade: nil)
	private static let variableAvailable = probe(fade: .top)

	static func isAvailable(variable: Bool) -> Bool {
		variable ? variableAvailable : plainAvailable
	}

	private static func probe(fade: Edge?) -> Bool {
		let view = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
		guard backdrop(of: view) != nil else {
			log.error("No backdrop layer in: \(view.subviews.map { String(describing: type(of: $0)) })")
			return false
		}
		guard make(radius: 1, fade: fade) != nil else {
			log.error("Blur filter unavailable, fade: \(fade != nil)")
			return false
		}
		return true
	}

	/// The subview whose layer is a CABackdropLayer. `.regular` has one; the `.system…Material` styles don't.
	static func backdrop(of view: UIVisualEffectView) -> UIView? {
		guard let layerClass = NSClassFromString(layerClassName) else { return nil }
		return view.subviews.first { $0.layer.isKind(of: layerClass) }
	}

	/// Returns nil if the filter can't be made. CAFilter takes any key without throwing, so the keys aren't checked first.
	static func make(radius: CGFloat, fade: Edge?) -> NSObject? {
		guard let filterClass = NSClassFromString(className) as? NSObject.Type else {
			log.error("No filter class")
			return nil
		}
		guard filterClass.responds(to: factory) else {
			log.error("Filter class has no factory")
			return nil
		}
		let type = fade == nil ? "gaussianBlur" : "variableBlur"
		guard let filter = unsafe filterClass.perform(factory, with: type)?.takeUnretainedValue() as? NSObject else {
			log.error("Factory gave no filter for \(type)")
			return nil
		}
		filter.setValue(radius, forKey: "inputRadius")
		filter.setValue(true, forKey: "inputNormalizeEdges")
		if let fade {
			guard let mask = mask(fade: fade) else {
				log.error("Mask image could not be built")
				return nil
			}
			filter.setValue(mask, forKey: "inputMaskImage")
		}
		return filter
	}

	/// The filter stretches this over the layer, so it doesn't need the view's size. Blur follows the alpha:
	/// opaque where it's strongest, clear at the `fade` edge.
	private static func mask(fade: Edge) -> CGImage? {
		let size = 64
		guard let space = CGColorSpace(name: CGColorSpace.linearGray),
		      let context = unsafe CGContext(
		      	data: nil, width: size, height: size, bitsPerComponent: 8,
		      	bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		      ),
		      let ramp = unsafe CGGradient(colorSpace: space, colorComponents: [0, 1, 0, 0], locations: [0, 1], count: 2)
		else {
			return nil
		}
		// CGContext's origin is bottom-left, so "top" means y = size.
		let far = CGFloat(size)
		let (start, end): (CGPoint, CGPoint) = switch fade {
			case .top: (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: far))
			case .bottom: (CGPoint(x: 0, y: far), CGPoint(x: 0, y: 0))
			case .leading: (CGPoint(x: far, y: 0), CGPoint(x: 0, y: 0))
			case .trailing: (CGPoint(x: 0, y: 0), CGPoint(x: far, y: 0))
		}
		context.drawLinearGradient(ramp, start: start, end: end, options: [])
		return context.makeImage()
	}
}

/// Only here for its backdrop layer, which blurs what's behind it live. `.regular` is the style that has one, and
/// its filters get replaced with ours, so nothing of `.regular` is left on screen.
private final class BackdropBlurUIView: UIVisualEffectView {
	private var radius: CGFloat
	private var fade: Edge?
	private var filter: NSObject?

	init(radius: CGFloat, fade: Edge?) {
		self.radius = radius
		self.fade = fade
		super.init(effect: UIBlurEffect(style: .regular))
		isUserInteractionEnabled = false
		apply()
		// UIKit rebuilds the effect's tint when the app returns to the foreground.
		NotificationCenter.default.addObserver(
			self, selector: #selector(reapply),
			name: UIApplication.didBecomeActiveNotification, object: nil
		)
	}

	@objc private func reapply() {
		apply()
		// UIKit may still be restoring the effect, so check again once it's done.
		DispatchQueue.main.async { [weak self] in self?.apply() }
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError()
	}

	func update(radius: CGFloat, fade: Edge?) {
		guard radius != self.radius || fade != self.fade else { return }
		self.radius = radius
		self.fade = fade
		apply()
	}

	override func didMoveToWindow() {
		super.didMoveToWindow()
		// Backdrops sample at a low resolution by default, which shows as blocks at small radii.
		guard let window, let layer = BackdropBlurFilter.backdrop(of: self)?.layer,
		      layer.responds(to: NSSelectorFromString("setScale:"))
		else {
			return
		}
		layer.setValue(window.traitCollection.displayScale, forKey: "scale")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		// In case UIKit puts its own filters back
		if let filter, let backdrop = BackdropBlurFilter.backdrop(of: self), backdrop.layer.filters?.first as? NSObject !== filter {
			backdrop.layer.filters = [filter]
		}
		hideTint()
	}

	/// A layer doesn't reliably see changes to a filter it already has, so any change makes a new one.
	private func apply() {
		guard let backdrop = BackdropBlurFilter.backdrop(of: self),
		      let filter = BackdropBlurFilter.make(radius: radius, fade: fade)
		else {
			filter = nil
			effect = UIBlurEffect(style: .systemUltraThinMaterial)
			return
		}
		self.filter = filter
		backdrop.layer.filters = [filter]
		hideTint()
	}

	/// `.regular`'s tint sits above the backdrop; hide it for a pure blur. UIKit puts it back at times, so this is repeated.
	private func hideTint() {
		guard filter != nil else { return }
		let backdrop = BackdropBlurFilter.backdrop(of: self)
		for subview in subviews where subview !== backdrop {
			subview.alpha = 0
			subview.isHidden = true
		}
	}
}
