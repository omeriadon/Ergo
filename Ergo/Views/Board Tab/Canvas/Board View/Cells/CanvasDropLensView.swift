//
//  CanvasDropLensView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

#if os(iOS)
	import ErgoLogic
	import SwiftUI
	import UIKit

	/// Holds `CanvasDropLens`'s SwiftUI, and grows it in and shrinks it away. Following the finger is only `center`, so
	/// SwiftUI only hears about it coming and going.
	final class CanvasDropLensView: UIView {
		private let hosted = canvasHost(CanvasDropLens(isLifted: false))
		private var isShown = false

		/// Fading is all that's left under Reduce Motion
		private var hiddenTransform: CGAffineTransform {
			unsafe UIAccessibility.isReduceMotionEnabled ? .identity : CGAffineTransform(scaleX: 0.5, y: 0.5)
		}

		init() {
			super.init(frame: CGRect(origin: .zero, size: CanvasDropLens.size))
			isUserInteractionEnabled = false
			alpha = 0
			transform = hiddenTransform

			hosted.view.frame = bounds
			addSubview(hosted.view)
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use init()")
		}

		func setShown(_ shown: Bool) {
			guard shown != isShown else { return }
			isShown = shown
			hosted.rootView = CanvasDropLens(isLifted: shown)
			UIView.animate(springDuration: 0.35, bounce: shown ? 0.3 : 0) {
				alpha = shown ? 1 : 0
				transform = shown ? .identity : hiddenTransform
			}
		}
	}
#endif
