//
//  SyncController+Syncing.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import SwiftUI
#if os(iOS)
	import UIKit
#endif

extension SyncController {
	// MARK: - Syncing

	var canSync: Bool {
		isSignedIn && isReady && !isLeaving
	}

	/// Local changes wait for a pause, like `BoardStore`'s save
	func scheduleSync() {
		handle(.localChange)
	}

	/// Starts over from no failures, for when things just got better: active again, back online, or signed in
	func syncNow() {
		handle(.requestedNow)
	}

	/// Waits out a backoff rather than adding to it
	func sync() {
		handle(.requested)
	}

	/// Syncs now and comes back once it's finished, for what needs the server and this device to agree before going on.
	/// Throws how it ended, if that's badly.
	func syncAndWait() async throws {
		syncNow()
		while let task = syncing {
			await task.value
		}
		if case let .failed(message, unreachable) = outcome {
			throw ServiceError(code: unreachable ? .providerUnavailable : .internalError, message: message)
		}
	}

	#if os(iOS)
		/// A silent push. iOS can start the app just for this, before `run()` has got going. It uses the result to judge how
		/// often to wake the app.
		func syncForPush() async -> UIBackgroundFetchResult {
			if !isReady {
				try? await catalog.load()
				isReady = true
			}
			let cursor = replica.cursor
			do {
				try await syncAndWait()
			} catch {
				return .failed
			}
			return replica.cursor == cursor ? .noData : .newData
		}
	#else
		/// A silent push. The Mac doesn't judge how often to wake the app, so there's no result to give.
		func syncForPush() async {
			if !isReady {
				try? await catalog.load()
				isReady = true
			}
			try? await syncAndWait()
		}
	#endif

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
	func stop() {
		handle(.stopped)
		generation += 1
		syncing?.cancel()
		syncing = nil
		stopListening()
	}
}
