//
//  AppUpdateWarning.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
import ErgoClient
import ErgoProtocol
#if os(iOS)
	import UIKit
#else
	import AppKit
#endif

/// Shows a badge when the server says this version of Ergo is getting old, or is too old to be answered.
///
/// `ErgoClient` says so on every reply, which can be many a minute, so this decides how often it's worth saying: at most
/// once each time the app comes to the front, and for an app that still works, at most once a day.
final class AppUpdateWarning {
	static let shared = AppUpdateWarning()

	private var shownSinceForeground = false
	private var observers: [any NSObjectProtocol] = []

	private static let daily: TimeInterval = 24 * 60 * 60

	func start() {
		guard observers.isEmpty else { return }

		observers.append(NotificationCenter.default.addObserver(forName: ErgoClient.appUpdateNotification, object: nil, queue: nil) { notification in
			guard let update = notification.object as? AppUpdate else { return }
			Task { @MainActor in
				AppUpdateWarning.shared.heard(update)
			}
		})
		#if os(iOS)
			let foreground = UIApplication.willEnterForegroundNotification
		#else
			let foreground = NSApplication.willBecomeActiveNotification
		#endif
		observers.append(NotificationCenter.default.addObserver(forName: foreground, object: nil, queue: nil) { _ in
			Task { @MainActor in
				AppUpdateWarning.shared.shownSinceForeground = false
			}
		})
	}

	private func heard(_ update: AppUpdate) {
		guard !shownSinceForeground else { return }
		if update == .recommended, let last = Defaults[.updateWarningShown], Date.now.timeIntervalSince(last) < Self.daily {
			return
		}

		shownSinceForeground = true
		Defaults[.updateWarningShown] = .now

		switch update {
			case .recommended:
				StatusBadgeManager.shared.addBadge(
					id: UUID(),
					title: "Update Ergo",
					secondaryText: "This version will stop working with the server soon.",
					priority: 5,
					view: .warning,
					width: .flexible
				)

			case .required:
				StatusBadgeManager.shared.addBadge(
					id: UUID(),
					title: "Update Ergo",
					secondaryText: "This version is too old to reach the server.",
					priority: 5,
					view: .error,
					width: .flexible
				)
		}
	}
}
