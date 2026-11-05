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

/// Keeps pages, bookmarks and synced settings the same on every device signed in to the same account,
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

	private(set) var status = Status.notSynced

	/// Pages that stay on this device because they're over the server's size limit
	private(set) var oversizedPages: [String] = []

	var isSignedIn: Bool {
		account.signedIn != nil
	}

	@ObservationIgnored private let account: TranslationAccount
	@ObservationIgnored private let pageStore: PageStore
	@ObservationIgnored private let catalog: CatalogStore

	@ObservationIgnored private var replica: SyncReplica

	/// The account `replica` is syncing with, so a change of account is noticed however it happens.
	/// Without its email, so adding one to the account doesn't start over.
	@ObservationIgnored private var syncingAccount: SignedInAccount?

	init(account: TranslationAccount, pageStore: PageStore, catalog: CatalogStore) {
		self.account = account
		self.pageStore = pageStore
		self.catalog = catalog
		replica = Defaults[.syncState] ?? SyncReplica(device: Self.deviceID())
		syncingAccount = account.signedIn?.withoutEmail

		pageStore.didSave = { [weak self] changed, deleted in
			self?.record(changed, deleted: deleted)
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
	@ObservationIgnored private var isReady = false

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

	@ObservationIgnored private var isOnline = true

	private func watchNetwork() async {
		for await path in NWPathMonitor() {
			let wasOnline = isOnline
			isOnline = path.status == .satisfied
			if isOnline, !wasOnline {
				syncNow()
			} else if !isOnline, status != .syncing, isSignedIn {
				status = .waitingForNetwork
			}
		}
	}

	// MARK: - Scene

	@ObservationIgnored private var isActive = true

	func scenePhaseChanged(_ phase: ScenePhase) {
		isActive = phase == .active
		switch phase {
			case .active:
				syncNow()
				startListening()
			case .background:
				stopListening()
				flush()
			default:
				stopListening()
		}
	}

	// MARK: - Account

	/// Sign-ins and sign-outs land here, whichever way they happened
	func accountChanged() {
		guard account.signedIn?.withoutEmail != syncingAccount else { return }
		syncingAccount = account.signedIn?.withoutEmail

		stop()
		// Keeps what's merged and pending, so signing in again, to any account, loses nothing
		replica.reset()
		saveReplica()
		status = .notSynced

		// Before it's ready, `run()` does this once it is
		if isSignedIn, isReady {
			recordAll()
			syncNow()
			startListening()
		}
	}

	func signIn(identityToken: String, nonce: String) async throws {
		try await account.signInWithApple(identityToken: identityToken, nonce: nonce)
		accountChanged()
	}

	/// Signed out, this signs in with the account this device already has. Signed in, it only adds a way in.
	func register(email: String, password: String) async throws {
		try await account.register(email: email, password: password)
		accountChanged()
	}

	func logIn(email: String, password: String) async throws {
		try await account.logIn(email: email, password: password)
		accountChanged()
	}

	func signOut() async throws {
		try await leaving { try await account.signOut() }
	}

	func deleteAccount() async throws {
		try await leaving { try await account.deleteAccount() }
	}

	@ObservationIgnored private var isLeaving = false

	/// Nothing syncs while the account goes, so no request races the token being deleted
	private func leaving(_ work: () async throws -> Void) async throws {
		stop()
		isLeaving = true
		defer { isLeaving = false }
		do {
			try await work()
		} catch {
			isLeaving = false
			syncNow()
			startListening()
			throw error
		}
		accountChanged()
	}

	// MARK: - Local changes

	@ObservationIgnored private var debounce: Task<Void, Never>?

	private func record(_ pages: [LogicPage], deleted: Set<LogicPage.ID>) {
		guard isSignedIn else { return }

		var changed = false
		for page in pages {
			guard let fields = try? PageRecord.fields(of: page) else { continue }
			changed = replica.recordLocal(kind: .page, id: PageRecord.id(page.id), fields: fields) || changed
		}
		for id in deleted {
			changed = replica.recordLocal(kind: .page, id: PageRecord.id(id), fields: [SyncFieldName.deleted: true]) || changed
		}
		if changed {
			saveReplica()
			scheduleSync()
		}
	}

	private func record(_ setting: SyncedSetting) {
		guard let value = setting.localValue else { return }
		if replica.recordLocal(kind: .setting, id: setting.rawValue, fields: [SyncFieldName.value: value]) {
			scheduleSync()
		}
	}

	private func recordBookmarks() {
		let bookmarked = Set(Defaults[.bookmarks].map(\.id))
		var changed = false
		for id in bookmarked {
			changed = replica.recordLocal(kind: .bookmark, id: id, fields: [SyncFieldName.present: true]) || changed
		}

		// Only ones this catalog knows: the rest are another version's, never shown here, so never removed here
		let removed = replica.records.values.filter { record in
			record.kind == .bookmark
				&& record.fields[SyncFieldName.present]?.value == true
				&& !bookmarked.contains(record.id)
				&& catalog.index.resolve(record.id) != nil
		}
		for record in removed {
			changed = replica.recordLocal(kind: .bookmark, id: record.id, fields: [SyncFieldName.present: false]) || changed
		}
		if changed {
			scheduleSync()
		}
	}

	/// Everything as it is now, after signing in or anything missed while signed out.
	/// The replica only stamps what differs, so this costs a comparison per record.
	private func recordAll() {
		for setting in SyncedSetting.allCases {
			// Left alone if it holds a value this version can't read, so it isn't overwritten with a local default
			if let synced = replica[.setting, setting.rawValue]?.fields[SyncFieldName.value], !setting.canDecode(synced.value) {
				continue
			}
			record(setting)
		}
		recordBookmarks()

		// Deleted here while signed out. Only pages this version could show, so it never deletes one it skipped.
		let local = Set(pageStore.pages.map { PageRecord.id($0.id) })
		let missing = replica.records.values.filter { record in
			record.kind == .page
				&& !record.isDeleted
				&& !local.contains(record.id)
				&& PageRecord.page(from: record, local: nil) != nil
		}
		record(pageStore.pages, deleted: Set(missing.compactMap { UUID(uuidString: $0.id) }))
		saveReplica()
	}

	private func saveReplica() {
		Defaults[.syncState] = replica

		let oversized = replica.oversized.filter { $0.kind == .page }
		let letters = LogicLetters.resolved(Defaults[.logicLetters])
		oversizedPages = pageStore.pages
			.filter { oversized.contains(SyncRecord.Key(kind: .page, id: PageRecord.id($0.id))) }
			.map { $0.title(letters: letters) }
	}

	// MARK: - Remote changes

	private func write(_ applied: SyncApplied) {
		var pages: [LogicPage] = []
		var deleted: Set<LogicPage.ID> = []
		for record in applied.changed {
			switch record.kind {
				case .page:
					guard let id = UUID(uuidString: record.id) else { continue }
					if record.isDeleted {
						deleted.insert(id)
					} else if let page = PageRecord.page(from: record, local: pageStore.pages.first { $0.id == id }) {
						pages.append(page)
					}
				case .bookmark:
					BookmarkRecord.write(record, catalog: catalog.index)
				case .setting:
					if let setting = SyncedSetting(rawValue: record.id), let value = record.fields[SyncFieldName.value] {
						setting.write(value.value)
					}
				default:
					continue
			}
		}
		pageStore.applyRemote(pages, deleted: deleted)

		// Only a page's content is worth a copy. Everything else is last writer wins.
		for field in applied.superseded where field.kind == .page && field.field == SyncFieldName.content {
			guard let id = UUID(uuidString: field.id) else { continue }
			let page = pageStore.pages.first { $0.id == id }
			if let copy = PageRecord.copy(
				of: field.lost,
				descriptors: page?.descriptors ?? LogicLetters.emptyDescriptors,
				created: page?.created ?? field.lost.stamp.date
			) {
				pageStore.insertCopy(copy)
			}
		}
	}

	// MARK: - Syncing

	@ObservationIgnored private var syncing: Task<Void, Never>?
	@ObservationIgnored private var syncAgain = false

	/// Goes up whenever syncing stops for an account change, so a reply that arrives afterwards is dropped
	@ObservationIgnored private var generation = 0

	/// Local changes wait for a pause, like `PageStore`'s save
	private func scheduleSync() {
		debounce?.cancel()
		debounce = Task {
			try? await Task.sleep(for: .seconds(2))
			guard !Task.isCancelled else { return }
			sync()
		}
	}

	/// Starts over from no failures, for when things just got better: active again, back online, or signed in
	func syncNow() {
		failures = 0
		retry?.cancel()
		retry = nil
		sync()
	}

	/// Waits out a backoff rather than adding to it
	private func sync() {
		guard isSignedIn, isReady, !isLeaving, retry == nil else { return }
		debounce?.cancel()
		if syncing != nil {
			syncAgain = true
			return
		}

		let generation = generation
		syncing = Task {
			await syncUntilDone()
			// Stopped meanwhile, and maybe already replaced
			guard generation == self.generation else { return }
			syncing = nil
			if syncAgain {
				syncAgain = false
				sync()
			}
		}
	}

	private func syncUntilDone() async {
		let generation = generation
		var recovered: Set<ServiceError.Code> = []
		status = .syncing

		// Each round trip either has more to pull or more to push, so this ends; the cap is only a guard
		for _ in 0 ..< 100 {
			guard let client = account.syncClient else {
				// Signed in without a token, after restoring a backup without the Keychain
				account.forgetSignIn()
				accountChanged()
				return
			}
			// Typing that's waiting for its save goes in this request
			pageStore.save()
			let request = replica.makeRequest()

			do {
				let response = try await client.sync(request)
				guard generation == self.generation else { return }

				// Records typing from during the request first, so a remote edit that beats it becomes a copy
				pageStore.save()
				let applied = replica.apply(response, sent: request)
				// Written back before the replica is saved, so being killed in between only means pulling again
				write(applied)
				saveReplica()
				if !applied.syncAgain {
					break
				}
			} catch let error as ServiceError {
				guard generation == self.generation else { return }
				switch error.code {
					case .syncResetRequired where recovered.insert(error.code).inserted:
						replica.reset()
						saveReplica()
					case .invalidRequest where recovered.insert(error.code).inserted:
						// Most likely a stamp too far ahead: measure the clock again, and the replica restamps it
						replica.recalibrate()
						saveReplica()
					case .unauthorized:
						account.forgetToken()
						accountChanged()
						return
					case .signInRequired:
						account.forgetSignIn()
						accountChanged()
						return
					default:
						fail(error)
						return
				}
			} catch {
				// Cancelled by `stop()`, which moves the generation on
				guard generation == self.generation else { return }
				fail(ServiceError(code: .internalError, message: error.localizedDescription))
				return
			}
		}

		status = .upToDate(.now)
	}

	// MARK: - Failures

	@ObservationIgnored private var failures = 0
	@ObservationIgnored private var retry: Task<Void, Never>?

	private func fail(_ error: ServiceError) {
		// The client reports an unreachable server as `providerUnavailable`, and sync never runs a provider
		status = error.code == .providerUnavailable || !isOnline ? .waitingForNetwork : .failed(error.message)

		failures += 1
		retry = Task {
			try? await Task.sleep(for: Self.backoff(failures))
			guard !Task.isCancelled else { return }
			retry = nil
			sync()
		}
	}

	/// 2, 4, 8 … seconds, up to 5 minutes
	static func backoff(_ failures: Int) -> Duration {
		.seconds(min(2 << min(max(failures - 1, 0), 8), 300))
	}

	/// Stops everything in flight, and drops replies that are still on their way
	private func stop() {
		generation += 1
		syncing?.cancel()
		syncing = nil
		syncAgain = false
		debounce?.cancel()
		retry?.cancel()
		retry = nil
		stopListening()
	}

	// MARK: - Leaving the foreground

	@ObservationIgnored private var backgroundTask = UIBackgroundTaskIdentifier.invalid

	/// Pushes what's pending straight away, so closing the app here and opening it on another device works.
	/// iOS suspends an app soon after it leaves, so this asks for the few seconds a sync needs.
	private func flush() {
		pageStore.save()
		guard isSignedIn, !replica.pending.isEmpty, backgroundTask == .invalid else { return }

		backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Sync") { [weak self] in
			self?.endBackgroundTask()
		}
		syncNow()
		Task {
			while let task = self.syncing {
				await task.value
			}
			endBackgroundTask()
		}
	}

	private func endBackgroundTask() {
		guard backgroundTask != .invalid else { return }
		UIApplication.shared.endBackgroundTask(backgroundTask)
		backgroundTask = .invalid
	}

	// MARK: - Live

	@ObservationIgnored private var listening: Task<Void, Never>?

	/// Only while active: a closed app hears about changes when it opens
	private func startListening() {
		guard listening == nil, isActive, isSignedIn, isReady, !isLeaving else { return }
		listening = Task {
			await listen()
		}
	}

	private func stopListening() {
		listening?.cancel()
		listening = nil
	}

	private func listen() async {
		var drops = 0
		while !Task.isCancelled, let client = account.syncClient {
			let opened = Date.now
			do {
				for try await message in client.syncLive() {
					switch message {
						case let .changed(cursor):
							if replica.cursor.map({ cursor > $0 }) ?? true {
								syncNow()
							}
					}
				}
			} catch let error as ServiceError where error.code == .unauthorized {
				// Syncing finds out too, and signs out
				sync()
				break
			} catch {}
			guard !Task.isCancelled else { return }

			// A socket that stayed up a while was fine; one that keeps dropping straight away backs off
			drops = Date.now.timeIntervalSince(opened) > 60 ? 1 : drops + 1
			try? await Task.sleep(for: Self.backoff(drops))
			guard !Task.isCancelled else { return }

			// Whatever was pushed while it was down
			sync()
		}
		// A cancelled one may already be replaced
		guard !Task.isCancelled else { return }
		listening = nil
	}
}

// MARK: - Previews

/// Not debug-only: the previews that use it are compiled in release builds too
extension SyncController {
	static func preview(signedIn: Bool, email: String? = nil, status: Status = .notSynced) -> SyncController {
		let account = TranslationAccount(
			signedIn: signedIn ? SignedInAccount(server: ServerEnvironment.productionURL, id: UUID(), email: email) : nil
		)
		let sync = SyncController(account: account, pageStore: PageStore(), catalog: CatalogStore())
		sync.status = status
		return sync
	}
}
