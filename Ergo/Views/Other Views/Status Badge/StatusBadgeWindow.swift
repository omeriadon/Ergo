//
//  StatusBadgeWindow.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import SwiftUI
import UIKit

/// A second window that sits above the app's own and only holds `StatusBadgeOverlay`.
///
/// It's UIKit because a SwiftUI overlay on the root view is drawn underneath any sheet, and most of what fails in Ergo
/// fails inside one. A window is the only thing above a sheet. It's see-through, and it lets every touch fall to the app
/// below except the ones that land on the badge itself.
final class StatusBadgeWindow: UIWindow {
	private static var installed: StatusBadgeWindow?

	/// Once, when the app's scene exists. Never made key, so the keyboard and the app's own window carry on as they were.
	static func install() {
		guard installed == nil,
		      let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
		else { return }

		let host = UIHostingController(rootView: StatusBadgeOverlay().fontDesign(.rounded))
		host.view.backgroundColor = .clear

		let window = StatusBadgeWindow(windowScene: scene)
		window.windowLevel = .alert
		window.backgroundColor = .clear
		window.rootViewController = host
		window.isHidden = false
		installed = window
	}

	override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		guard StatusBadgeManager.shared.badgeFrame.contains(point) else {
			return nil
		}
		return super.hitTest(point, with: event)
	}
}
