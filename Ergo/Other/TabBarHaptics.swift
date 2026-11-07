//
//  TabBarHaptics.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import Defaults
import SwiftUI

/// A tap on the tab bar gives a haptic, even on the tab that's already selected. SwiftUI's `TabView` never reports that, so this listens to the tab bar itself with a tap recognizer that doesn't get in the way of the real tap.
private struct TabBarHaptics: UIViewControllerRepresentable {
	func makeUIViewController(context _: Context) -> Finder {
		Finder()
	}

	func updateUIViewController(_: Finder, context _: Context) {}

	final class Finder: UIViewController, UIGestureRecognizerDelegate {
		private let generator = UIImpactFeedbackGenerator(style: .light)
		private weak var tabBar: UITabBar?
		private var recognizer: UITapGestureRecognizer?

		override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)

			guard recognizer == nil, let tabBar = tabBarController?.tabBar ?? Self.tabBarController(in: view.window?.rootViewController)?.tabBar else {
				return
			}

			let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
			recognizer.cancelsTouchesInView = false
			recognizer.delaysTouchesEnded = false
			recognizer.delegate = self
			tabBar.addGestureRecognizer(recognizer)

			self.tabBar = tabBar
			self.recognizer = recognizer
		}

		deinit {
			MainActor.assumeIsolated {
				if let recognizer {
					tabBar?.removeGestureRecognizer(recognizer)
				}
			}
		}

		@objc private func tapped() {
			guard Defaults[.hapticsEnabled] else {
				return
			}

			generator.impactOccurred()
		}

		func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
			true
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
}

extension View {
	func tabBarHaptics() -> some View {
		background { TabBarHaptics() }
	}
}
