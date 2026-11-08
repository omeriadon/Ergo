//
//  AppDelegate.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import UIKit
import UserNotifications

/// The only way iOS hands an app its push token, silent pushes and notification taps. SwiftUI has nothing for these, so
/// this is a thin layer that passes them on.
///
/// iOS can start the app in the background for a push, with no view on screen, so what it needs is set in `ErgoApp.init`
/// rather than read from the environment.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
	static var sync: SyncController?
	static var navigation: NavigationManager?
	static var boardStore: BoardStore?

	func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		UNUserNotificationCenter.current().delegate = self
		return true
	}

	// MARK: - Push

	func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		Self.sync?.uploadPushToken(deviceToken)
	}

	/// Sync still works without pushes, it just finds out when the app next opens
	func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError _: any Error) {}

	func application(
		_: UIApplication,
		didReceiveRemoteNotification _: [AnyHashable: Any],
		fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
	) {
		guard let sync = Self.sync else {
			completionHandler(.noData)
			return
		}
		Task {
			await completionHandler(sync.syncForPush())
		}
	}

	// MARK: - Notifications

	/// A banner about the board on screen would only say what the person can see. These two are `nonisolated` because iOS
	/// doesn't promise to call them on the main actor.
	nonisolated func userNotificationCenter(
		_: UNUserNotificationCenter,
		willPresent notification: UNNotification,
		withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
	) {
		let board = Self.board(of: notification)
		Task { @MainActor in
			let isOpen = Self.navigation?.selectedTab == .board && board != nil && Self.boardStore?.current.id == board
			completionHandler(isOpen ? [] : [.banner, .list, .sound])
		}
	}

	nonisolated func userNotificationCenter(
		_: UNUserNotificationCenter,
		didReceive response: UNNotificationResponse,
		withCompletionHandler completionHandler: @escaping @Sendable () -> Void
	) {
		let board = Self.board(of: response.notification)
		Task { @MainActor in
			await Self.open(board)
			completionHandler()
		}
	}

	/// The push can get here ahead of the sync that brings the board, so it syncs first when the board isn't here yet.
	/// A board that's gone (someone was removed, or it was deleted) just opens the tab.
	private static func open(_ board: UUID?) async {
		guard let navigation, let boardStore else { return }
		navigation.selectedTab = .board
		navigation.dismissSheet()

		guard let board else { return }
		if !boardStore.boards.contains(where: { $0.id == board }) {
			_ = await sync?.syncForPush()
		}
		if boardStore.boards.contains(where: { $0.id == board }) {
			boardStore.open(board)
		}
	}

	private nonisolated static func board(of notification: UNNotification) -> UUID? {
		(notification.request.content.userInfo["board"] as? String).flatMap(UUID.init(uuidString:))
	}
}
