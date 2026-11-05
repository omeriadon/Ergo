//
//  ScrollSync.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class ScrollSync {
	enum Source {
		case top, bottom
	}

	/// The only observed value, read by the page indicator
	private(set) var progress: CGFloat = 0

	@ObservationIgnored private weak var top: UIScrollView?
	@ObservationIgnored private weak var bottom: UIScrollView?

	/// Whichever row the finger is on, the other one follows
	@ObservationIgnored private var source: Source?

	static func progress(of geometry: ScrollGeometry) -> CGFloat {
		let distance = max(
			0,
			geometry.contentSize.width - geometry.containerSize.width
		)

		return distance > 0
			? min(max(geometry.contentOffset.x / distance, 0), 1)
			: 0
	}

	func register(_ scroll: UIScrollView, for source: Source) {
		switch source {
			case .top:
				top = scroll
			case .bottom:
				bottom = scroll
		}
	}

	func phaseChanged(_ source: Source, to phase: ScrollPhase) {
		if phase == .interacting {
			self.source = source
		} else if phase == .idle, self.source == source {
			self.source = nil
		}
	}

	func scrolled(_ source: Source, to progress: CGFloat) {
		guard self.source == source else { return }

		if abs(self.progress - progress) > 0.001 {
			self.progress = progress
		}

		move(source == .top ? bottom : top, to: progress)
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

		private func resolve() {
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
