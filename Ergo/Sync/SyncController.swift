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
	private enum Outcome: Equatable {
		case succeeded(Date)
		case failed(String, unreachable: Bool)
	}

	private var schedule = SyncSchedule()
	private var outcome: Outcome?

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
	private(set) var oversizedBoards: [String] = []

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

	@ObservationIgnored private let account: TranslationAccount
	@ObservationIgnored private let boardStore: BoardStore
	@ObservationIgnored private let scratchpadStore: ScratchpadStore
	@ObservationIgnored private let catalog: CatalogStore

	@ObservationIgnored private var replica: SyncReplica

	/// The account `replica` is syncing with, so a change of account is noticed however it happens.
	/// Without its email, so adding one to the account doesn't start over.
	@ObservationIgnored private var syncingAccount: SignedInAccount?

	init(account: TranslationAccount, boardStore: BoardStore, scratchpadStore: ScratchpadStore, catalog: CatalogStore) {
		self.account = account
		self.boardStore = boardStore
		self.scratchpadStore = scratchpadStore
		self.catalog = catalog
		replica = Defaults[.syncState] ?? SyncReplica(device: Self.deviceID())
		syncingAccount = account.signedIn?.withoutEmail

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

	private var isOnline = true

	private func watchNetwork() async {
		for await path in NWPathMonitor() {
			let wasOnline = isOnline
			isOnline = path.status == .satisfied
			if isOnline, !wasOnline {
				syncNow()
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
		outcome = nil

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

	/// Other devices are signed out and find out from their next request. This one stays as it is.
	func changePassword(current: String, new: String) async throws {
		try await account.changePassword(current: current, new: new)
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
		do {
			try await work()
		} catch {
			isLeaving = false
			syncNow()
			startListening()
			throw error
		}
		isLeaving = false
		accountChanged()
	}

	// MARK: - Local changes

	private func record(_ boards: [Board], deleted: Set<Board.ID>) {
		guard isSignedIn else { return }

		// Before anything is recorded: a link to a statement deleted here only counts as the board's while that statement lives
		let removed = removedRecords(from: boards)

		var changed = false
		for board in boards {
			if let fields = try? BoardRecord.fields(of: board) {
				changed = replica.recordLocal(kind: .board, id: BoardRecord.id(board.id), fields: fields) || changed
			}
			for statement in board.statements {
				guard let fields = try? StatementRecord.fields(of: statement, in: board.id) else { continue }
				changed = replica.recordLocal(kind: .statement, id: StatementRecord.id(statement.id), fields: fields) || changed
			}
			for link in board.links {
				changed = replica.recordLocal(kind: .link, id: LinkRecord.id(link.id), fields: LinkRecord.fields(of: link, in: board.id)) || changed
			}
		}
		for (kind, id) in removed {
			changed = replica.recordLocal(kind: kind, id: id, fields: [SyncFieldName.deleted: true]) || changed
		}
		// Only the board's tombstone: its statements and links are ignored with it, and the server prunes them
		for id in deleted {
			changed = replica.recordLocal(kind: .board, id: BoardRecord.id(id), fields: [SyncFieldName.deleted: true]) || changed
		}
		if changed {
			saveReplica()
			scheduleSync()
		}
	}

	/// Statements and links the replica has alive for these boards that the boards no longer have, because they were
	/// deleted here. Only ones this version can read, and never ones the replica ignores (their board or statement
	/// might just not have arrived), so it never deletes what it hasn't shown.
	private func removedRecords(from boards: [Board]) -> [(kind: SyncKind, id: String)] {
		let local = Dictionary(boards.map { (BoardRecord.id($0.id), $0) }) { first, _ in first }
		var removed: [(kind: SyncKind, id: String)] = []
		for record in replica.records.values where !record.isDeleted {
			guard let owner = record.owningBoard, let board = local[owner], !replica.isIgnored(record) else { continue }
			switch record.kind {
				case .statement:
					if StatementRecord.canRead(record), !board.statements.contains(where: { StatementRecord.id($0.id) == record.id }) {
						removed.append((.statement, record.id))
					}
				case .link:
					if LinkRecord.link(from: record) != nil, !board.links.contains(where: { LinkRecord.id($0.id) == record.id }) {
						removed.append((.link, record.id))
					}
				default:
					break
			}
		}
		return removed
	}

	private func recordScratchpads(_ scratchpads: [LogicScratchpad], deleted: Set<LogicScratchpad.ID>) {
		guard isSignedIn else { return }

		var changed = false
		for scratchpad in scratchpads {
			if let fields = try? ScratchpadRecord.fields(of: scratchpad) {
				changed = replica.recordLocal(kind: .scratchpad, id: ScratchpadRecord.id(scratchpad.id), fields: fields) || changed
			}
		}
		for id in deleted {
			changed = replica.recordLocal(kind: .scratchpad, id: ScratchpadRecord.id(id), fields: [SyncFieldName.deleted: true]) || changed
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

		// Deleted here while signed out. Only boards this version could show, so it never deletes one it skipped.
		let local = Set(boardStore.boards.map { BoardRecord.id($0.id) })
		let missing = replica.records.values.filter { record in
			record.kind == .board
				&& !record.isDeleted
				&& !local.contains(record.id)
				&& BoardRecord.canRead(record)
		}
		record(boardStore.boards, deleted: Set(missing.compactMap { UUID(uuidString: $0.id) }))

		// The same for scratchpads
		let localScratchpads = Set(scratchpadStore.scratchpads.map { ScratchpadRecord.id($0.id) })
		let missingScratchpads = replica.records.values.filter { record in
			record.kind == .scratchpad
				&& !record.isDeleted
				&& !localScratchpads.contains(record.id)
				&& ScratchpadRecord.canRead(record)
		}
		recordScratchpads(scratchpadStore.scratchpads, deleted: Set(missingScratchpads.compactMap { UUID(uuidString: $0.id) }))
		saveReplica()
	}

	private func saveReplica() {
		Defaults[.syncState] = replica

		let oversized = replica.oversized
		oversizedBoards = boardStore.boards
			.filter { board in
				oversized.contains(SyncRecord.Key(kind: .board, id: BoardRecord.id(board.id)))
					|| board.statements.contains { oversized.contains(SyncRecord.Key(kind: .statement, id: StatementRecord.id($0.id))) }
			}
			.map(\.title)

		let letters = LogicLetters.resolved(Defaults[.logicLetters])
		oversizedBoards += scratchpadStore.scratchpads
			.filter { oversized.contains(SyncRecord.Key(kind: .scratchpad, id: ScratchpadRecord.id($0.id))) }
			.map { $0.title(letters: letters) }
	}

	// MARK: - Remote changes

	/// `pullComplete` is false while more is still coming. A statement a link joins can be missing only because it
	/// hasn't arrived yet, so links are only cleaned up once everything has.
	private func write(_ applied: SyncApplied, pullComplete: Bool) {
		var affected: Set<Board.ID> = []
		var affectedScratchpads: Set<LogicScratchpad.ID> = []
		for record in applied.changed {
			switch record.kind {
				case .board:
					if let id = UUID(uuidString: record.id) {
						affected.insert(id)
					}
				case .statement, .link:
					if let id = record.owningBoard.flatMap(UUID.init(uuidString:)) {
						affected.insert(id)
					}
				case .scratchpad:
					if let id = UUID(uuidString: record.id) {
						affectedScratchpads.insert(id)
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

		// Boards are built from the replica as a whole, so the order records arrived in doesn't matter
		let rebuilt = BoardRecord.rebuild(affected, from: replica, local: boardStore.boards)
		boardStore.applyRemote(rebuilt.boards, deleted: rebuilt.deleted)

		// Only a statement's content is worth a copy. Everything else is last writer wins.
		for field in applied.superseded(.statement, field: SyncFieldName.content) {
			guard
				let id = UUID(uuidString: field.id),
				let board = boardStore.boards.first(where: { $0.statement(id) != nil }),
				let copy = StatementRecord.copy(of: field.lost, beside: id, in: board)
			else {
				continue
			}
			boardStore.insertStatementCopy(copy, into: board.id)
		}

		let rebuiltScratchpads = ScratchpadRecord.rebuild(affectedScratchpads, from: replica, local: scratchpadStore.scratchpads)
		scratchpadStore.applyRemote(rebuiltScratchpads.scratchpads, deleted: rebuiltScratchpads.deleted)

		// A scratchpad's content is worth a copy too
		for field in applied.superseded(.scratchpad, field: SyncFieldName.content) {
			guard
				let id = UUID(uuidString: field.id),
				let original = scratchpadStore.scratchpads.first(where: { $0.id == id }),
				let copy = ScratchpadRecord.copy(of: field.lost, beside: original)
			else {
				continue
			}
			scratchpadStore.insertCopy(copy)
		}

		if pullComplete {
			deleteDanglingLinks()
		}
	}

	/// A link whose statement is gone on a board that isn't. Another device deleted the statement without its links,
	/// or drew one to it at the same moment. The replica ignores it, so this makes that permanent.
	private func deleteDanglingLinks() {
		func isGone(_ kind: SyncKind, _ id: String) -> Bool {
			replica[kind, id].map(\.isDeleted) ?? true
		}

		let dangling = replica.records.values.filter { record in
			guard record.kind == .link, !record.isDeleted, let board = record.owningBoard, let ends = record.joined else { return false }
			return !isGone(.board, board) && (isGone(.statement, ends.premise) || isGone(.statement, ends.conclusion))
		}

		var changed = false
		for record in dangling {
			changed = replica.recordLocal(kind: .link, id: record.id, fields: [SyncFieldName.deleted: true]) || changed
		}
		if changed {
			saveReplica()
			scheduleSync()
		}
	}

	// MARK: - Syncing

	@ObservationIgnored private var syncing: Task<Void, Never>?

	/// The one timer `schedule` asks for: the pause after a local change, or a backoff
	@ObservationIgnored private var timer: Task<Void, Never>?

	/// Goes up whenever syncing stops for an account change, so a reply that arrives afterwards is dropped
	@ObservationIgnored private var generation = 0

	private var canSync: Bool {
		isSignedIn && isReady && !isLeaving
	}

	/// Local changes wait for a pause, like `BoardStore`'s save
	private func scheduleSync() {
		handle(.localChange)
	}

	/// Starts over from no failures, for when things just got better: active again, back online, or signed in
	func syncNow() {
		handle(.requestedNow)
	}

	/// Waits out a backoff rather than adding to it
	private func sync() {
		handle(.requested)
	}

	private func handle(_ event: SyncSchedule.Event) {
		switch schedule.apply(event) {
			case .nothing:
				break
			case let .startTimer(delay):
				timer?.cancel()
				timer = Task {
					try? await Task.sleep(for: delay)
					guard !Task.isCancelled else { return }
					handle(.timerFired)
				}
			case .cancelTimer:
				cancelTimer()
			case .run:
				cancelTimer()
				startSyncing()
		}
	}

	private func cancelTimer() {
		timer?.cancel()
		timer = nil
	}

	private func startSyncing() {
		// Dropped, as when signed out. What's pending stays in the replica for the next sync.
		guard canSync else {
			handle(.succeeded)
			return
		}

		let generation = generation
		syncing = Task {
			let ending = await syncUntilDone()
			// Stopped meanwhile, and maybe already replaced
			guard generation == self.generation else { return }
			syncing = nil
			switch ending {
				case .finished:
					outcome = .succeeded(.now)
					handle(.succeeded)
				case let .failed(error):
					// The client reports an unreachable server as `providerUnavailable`, and sync never runs a provider
					outcome = .failed(error.message, unreachable: error.code == .providerUnavailable)
					handle(.failed)
				case .abandoned:
					handle(.succeeded)
			}
		}
	}

	private enum Ending {
		case finished
		case failed(ServiceError)
		/// Signed out, or stopped. Neither a success nor a failure.
		case abandoned
	}

	private func syncUntilDone() async -> Ending {
		let generation = generation
		var recovered: Set<ServiceError.Code> = []

		// Each round trip either has more to pull or more to push, so this ends; the cap is only a guard
		for _ in 0 ..< 100 {
			guard let client = account.syncClient else {
				// The Keychain couldn't be read, which says nothing about the token
				if account.syncTokenUnavailable {
					return .failed(TranslationAccount.keychainUnavailable)
				}
				// Signed in without a token, after restoring a backup without the Keychain
				account.forgetSignIn()
				accountChanged()
				return .abandoned
			}
			// Typing that's waiting for its save goes in this request
			boardStore.save()
			scratchpadStore.save()
			let request = replica.makeRequest()

			do {
				let response = try await client.sync(request)
				guard generation == self.generation else { return .abandoned }

				// Records typing from during the request first, so a remote edit that beats it becomes a copy
				boardStore.save()
				scratchpadStore.save()
				let applied = replica.apply(response, sent: request)
				// Written back before the replica is saved, so being killed in between only means pulling again
				write(applied, pullComplete: !response.more)
				saveReplica()
				if !applied.syncAgain {
					return .finished
				}
			} catch let error as ServiceError {
				guard generation == self.generation else { return .abandoned }
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
						return .abandoned
					case .signInRequired:
						account.forgetSignIn()
						accountChanged()
						return .abandoned
					default:
						return .failed(error)
				}
			} catch {
				// Cancelled by `stop()`, which moves the generation on
				guard generation == self.generation else { return .abandoned }
				return .failed(ServiceError(code: .internalError, message: error.localizedDescription))
			}
		}

		return .failed(ServiceError(code: .internalError, message: "Expected sync to finish within 100 requests"))
	}

	/// Stops everything in flight, and drops replies that are still on their way
	private func stop() {
		handle(.stopped)
		generation += 1
		syncing?.cancel()
		syncing = nil
		stopListening()
	}

	// MARK: - Leaving the foreground

	@ObservationIgnored private var backgroundTask = UIBackgroundTaskIdentifier.invalid

	/// Pushes what's pending straight away, so closing the app here and opening it on another device works.
	/// iOS suspends an app soon after it leaves, so this asks for the few seconds a sync needs.
	private func flush() {
		boardStore.save()
		scratchpadStore.save()
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
		guard listening == nil, isActive, canSync else { return }
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
			try? await Task.sleep(for: SyncSchedule.backoff(drops))
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
		let sync = SyncController(account: account, boardStore: BoardStore(), scratchpadStore: ScratchpadStore(), catalog: CatalogStore())
		sync.seed(status)
		return sync
	}

	/// Shows `status` without syncing
	private func seed(_ status: Status) {
		switch status {
			case .notSynced:
				break
			case .syncing:
				_ = schedule.apply(.requested)
			case let .upToDate(date):
				outcome = .succeeded(date)
			case .waitingForNetwork:
				outcome = .failed("", unreachable: true)
			case let .failed(message):
				outcome = .failed(message, unreachable: false)
		}
	}
}
