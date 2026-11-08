//
//  SyncController.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import Network
import SwiftUI
import UIKit

/// Keeps boards, scratchpads, bookmarks and synced settings the same on every device signed in to the same account,
/// with Apple or an email.
///
/// It syncs on launch, on becoming active, 2 s after a local change, when another device pushes, and after signing
/// in. One sync runs at a time, failures back off, and nothing polls.
@MainActor
@Observable
final class SyncController {
	enum Status: Equatable {
		case notSynced
		case syncing
		case upToDate(Date)
		case waitingForNetwork
		case failed(String)
	}

	/// How the last sync ended, until the account changes
	enum Outcome: Equatable {
		case succeeded(Date)
		case failed(String, unreachable: Bool)
	}

	var schedule = SyncSchedule()
	var outcome: Outcome?

	var status: Status {
		if case .running = schedule.phase {
			return .syncing
		}
		guard isSignedIn else { return .notSynced }
		guard isOnline else { return .waitingForNetwork }
		switch outcome {
			case let .failed(message, unreachable):
				return unreachable ? .waitingForNetwork : .failed(message)
			case let .succeeded(date):
				return .upToDate(date)
			case nil:
				return .notSynced
		}
	}

	/// Boards and scratchpads that stay on this device because they're over the server's size limit
	var oversizedBoards: [String] = []

	var isSignedIn: Bool {
		account.signedIn != nil
	}

	/// Known only when this device signed in or registered with an email, and then the password can be changed
	var email: String? {
		account.signedIn?.email
	}

	/// Signed in with an email on this device, and not with Apple yet
	var canAddApple: Bool {
		email != nil && account.signedIn?.hasApple != true
	}

	@ObservationIgnored let account: TranslationAccount
	@ObservationIgnored let boardStore: BoardStore
	@ObservationIgnored let scratchpadStore: ScratchpadStore
	@ObservationIgnored let catalog: CatalogStore

	@ObservationIgnored var replica: SyncReplica

	/// The account `replica` is syncing with, so a change of account is noticed however it happens.
	/// Without its email, so adding one to the account doesn't start over.
	@ObservationIgnored var syncingAccount: SignedInAccount?

	var isOnline = true
	@ObservationIgnored var isActive = true
	@ObservationIgnored var isLeaving = false

	@ObservationIgnored var syncing: Task<Void, Never>?

	/// The one timer `schedule` asks for: the pause after a local change, or a backoff
	@ObservationIgnored var timer: Task<Void, Never>?

	/// Goes up whenever syncing stops for an account change, so a reply that arrives afterwards is dropped
	@ObservationIgnored var generation = 0

	@ObservationIgnored var backgroundTask = UIBackgroundTaskIdentifier.invalid

	@ObservationIgnored var listening: Task<Void, Never>?

	init(account: TranslationAccount, boardStore: BoardStore, scratchpadStore: ScratchpadStore, catalog: CatalogStore) {
		self.account = account
		self.boardStore = boardStore
		self.scratchpadStore = scratchpadStore
		self.catalog = catalog
		replica = Defaults[.syncState] ?? SyncReplica(device: Self.deviceID())
		syncingAccount = account.signedIn?.withoutEmail
		boardStore.shares = BoardShareRecords.shares(in: replica)

		boardStore.didSave = { [weak self] changed, deleted in
			self?.record(changed, deleted: deleted)
		}
		scratchpadStore.didSave = { [weak self] changed, deleted in
			self?.recordScratchpads(changed, deleted: deleted)
		}
	}

	private static func deviceID() -> String {
		if let id = Defaults[.syncDeviceID] {
			return id
		}
		let id = UUID().uuidString
		Defaults[.syncDeviceID] = id
		return id
	}

	// MARK: - Running

	@ObservationIgnored private var isRunning = false

	/// Nothing syncs before the catalog loads. A bookmark written back without it would be skipped,
	/// then look removed here and be removed everywhere.
	@ObservationIgnored var isReady = false

	/// Watches for local changes for as long as the app runs
	func run() async {
		guard !isRunning else { return }
		isRunning = true

		try? await catalog.load()
		isReady = true

		if isSignedIn {
			recordAll()
			syncNow()
			startListening()
			registerForPush()
		}

		await withDiscardingTaskGroup { group in
			group.addTask { await self.watchServer() }
			group.addTask { await self.watchBookmarks() }
			group.addTask { await self.watchNetwork() }
			for setting in SyncedSetting.allCases {
				group.addTask { await self.watch(setting) }
			}
		}
	}

	/// Either key can change which server is in use, and a change of server ends the sign-in on the old one:
	/// `serverChanged()` signs out, then `accountChanged()` stops syncing and listening and resets the replica
	private func watchServer() async {
		for await _ in Defaults.updates([.serverEnvironment, .translationServer]) {
			account.serverChanged()
			accountChanged()
		}
	}

	private func watchBookmarks() async {
		for await _ in Defaults.updates([.bookmarks], initial: false) {
			guard isSignedIn else { continue }
			recordBookmarks()
			saveReplica()
		}
	}

	private func watch(_ setting: SyncedSetting) async {
		for await _ in Defaults.updates([setting.key], initial: false) {
			guard isSignedIn else { continue }
			record(setting)
			saveReplica()
		}
	}

	private func watchNetwork() async {
		for await path in NWPathMonitor() {
			let wasOnline = isOnline
			isOnline = path.status == .satisfied
			if isOnline, !wasOnline {
				syncNow()
			}
		}
	}
}
