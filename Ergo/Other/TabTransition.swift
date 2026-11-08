//
//  TabTransition.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

extension UIViewController {
	/// The `UITabBarController` that SwiftUI's `TabView` sits on.
	func hostingTabBarController() -> UITabBarController? {
		tabBarController ?? Self.tabBarController(in: view.window?.rootViewController)
	}

	private static func tabBarController(in controller: UIViewController?) -> UITabBarController? {
		guard let controller else {
			return nil
		}

		if let tabBarController = controller as? UITabBarController {
			return tabBarController
		}

		for child in controller.children {
			if let found = tabBarController(in: child) {
				return found
			}
		}

		return tabBarController(in: controller.presentedViewController)
	}
}

/// Changing tab blurs and fades one tab into the other instead of cutting, and tapping the selected tab again is reported. SwiftUI's `TabView` has no way to animate that, so this gives its tab bar controller an animator, through a delegate that hands everything else to the delegate SwiftUI had already set.
private struct TabTransition: UIViewControllerRepresentable {
	let onReselect: () -> Void

	func makeUIViewController(context _: Context) -> Finder {
		Finder()
	}

	func updateUIViewController(_ finder: Finder, context _: Context) {
		finder.proxy.onReselect = onReselect
		finder.install()
	}

	final class Finder: UIViewController {
		let proxy = TabTransitionDelegate()
		private weak var host: UITabBarController?

		override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
			install()
		}

		/// SwiftUI may set its own delegate again, so this is safe to repeat.
		func install() {
			guard let host = hostingTabBarController(), host.delegate !== proxy else {
				return
			}

			proxy.forwardee = host.delegate
			host.delegate = proxy
			self.host = host
		}

		deinit {
			MainActor.assumeIsolated {
				if host?.delegate === proxy {
					host?.delegate = proxy.forwardee
				}
			}
		}
	}
}

private final nonisolated class TabTransitionDelegate: NSObject, UITabBarControllerDelegate {
	weak var forwardee: any UITabBarControllerDelegate?
	var onReselect: () -> Void = {}

	/// UIKit asks this for every tap on a tab, including the one that's already selected, which SwiftUI's `TabView` never reports.
	func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
		if tab.identifier == tabBarController.selectedTab?.identifier {
			onReselect()
		}

		return forwardee?.tabBarController?(tabBarController, shouldSelectTab: tab) ?? true
	}

	func tabBarController(_: UITabBarController, animationControllerForTransitionFrom _: UIViewController, to _: UIViewController) -> any UIViewControllerAnimatedTransitioning? {
		TabBlurAnimator()
	}

	override func responds(to aSelector: Selector!) -> Bool {
		super.responds(to: aSelector) || forwardee?.responds(to: aSelector) == true
	}

	override func forwardingTarget(for aSelector: Selector!) -> Any? {
		forwardee?.responds(to: aSelector) == true ? forwardee : nil
	}
}

/// Blurs with the same private filter as `BackdropBlur`, on the tabs' own layers. The tab bar isn't in the transition's container, so it stays sharp.
private final class TabBlurAnimator: NSObject, UIViewControllerAnimatedTransitioning {
	private static let duration: TimeInterval = 0.25
	private static let radius: CGFloat = 16
	private static let filterName = "tabTransitionBlur"

	func transitionDuration(using _: any UIViewControllerContextTransitioning?) -> TimeInterval {
		Self.duration
	}

	func animateTransition(using context: any UIViewControllerContextTransitioning) {
		guard let from = context.view(forKey: .from), let to = context.view(forKey: .to) else {
			context.completeTransition(false)
			return
		}

		if let controller = context.viewController(forKey: .to) {
			to.frame = context.finalFrame(for: controller)
		}

		context.containerView.addSubview(to)
		to.alpha = 0

		let blurs = unsafe !UIAccessibility.isReduceMotionEnabled
		if blurs {
			Self.blur(to, from: Self.radius, to: 0)
			Self.blur(from, from: 0, to: Self.radius)
		}

		UIView.animate(withDuration: Self.duration, delay: 0, options: .curveEaseInOut) {
			from.alpha = 0
			to.alpha = 1
		} completion: { _ in
			from.alpha = 1
			Self.unblur(from)
			Self.unblur(to)
			context.completeTransition(!context.transitionWasCancelled)
		}
	}

	/// A layer doesn't reliably see changes to a filter it already has, so the radius is animated by key path instead, through the filter's name. If the filter can't be made, the tab just fades.
	private static func blur(_ view: UIView, from: CGFloat, to: CGFloat) {
		guard let filter = BackdropBlurFilter.make(radius: from, fade: nil) else {
			return
		}

		filter.setValue(filterName, forKey: "name")
		view.layer.filters = [filter]

		let animation = CABasicAnimation(keyPath: "filters.\(filterName).inputRadius")
		animation.fromValue = from
		animation.toValue = to
		animation.duration = duration
		animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
		animation.fillMode = .forwards
		animation.isRemovedOnCompletion = false
		view.layer.add(animation, forKey: filterName)
	}

	private static func unblur(_ view: UIView) {
		view.layer.removeAnimation(forKey: filterName)
		view.layer.filters = nil
	}
}

extension View {
	/// `onReselect` runs when the tab that's already selected is tapped.
	func tabTransition(onReselect: @escaping () -> Void) -> some View {
		background { TabTransition(onReselect: onReselect) }
	}
}
