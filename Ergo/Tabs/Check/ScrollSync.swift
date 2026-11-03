//
//  ScrollSync.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import SwiftUI
import UIKit

@MainActor
final class ScrollSync {
	weak var top: UIScrollView?
	weak var bottom: UIScrollView?

	func moveTop(to progress: CGFloat) {
		move(top, to: progress)
	}

	func moveBottom(to progress: CGFloat) {
		move(bottom, to: progress)
	}

	private func move(_ scroll: UIScrollView?, to progress: CGFloat) {
		guard let scroll else { return }

		let distance = max(
			0,
			scroll.contentSize.width - scroll.bounds.width
		)

		let x = min(max(progress, 0), 1) * distance

		guard abs(scroll.contentOffset.x - x) > 0.1 else {
			return
		}

		scroll.setContentOffset(
			CGPoint(x: x, y: scroll.contentOffset.y),
			animated: false
		)
	}
}

struct ScrollViewResolver: UIViewRepresentable {
	let onResolve: (UIScrollView) -> Void

	func makeUIView(context _: Context) -> ResolverView {
		let view = ResolverView()
		view.onResolve = onResolve
		return view
	}

	func updateUIView(_ view: ResolverView, context _: Context) {
		view.onResolve = onResolve
		view.resolve()
	}

	final class ResolverView: UIView {
		var onResolve: ((UIScrollView) -> Void)?

		override func didMoveToSuperview() {
			super.didMoveToSuperview()
			resolve()
		}

		override func didMoveToWindow() {
			super.didMoveToWindow()
			resolve()
		}

		func resolve() {
			var current = superview

			while let view = current {
				if let scroll = view as? UIScrollView {
					scroll.bouncesHorizontally = false

					scroll.delaysContentTouches = false
					scroll.canCancelContentTouches = true

					onResolve?(scroll)
					return
				}
				current = view.superview
			}
		}
	}
}
