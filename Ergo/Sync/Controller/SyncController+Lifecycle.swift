//
//  SyncController+Lifecycle.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import SwiftUI
import UIKit

extension SyncController {
	// MARK: - Scene

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

	// MARK: - Leaving the foreground

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

	/// Only while active: a closed app hears about changes when it opens
	func startListening() {
		guard listening == nil, isActive, canSync else { return }
		listening = Task {
			await listen()
		}
	}

	func stopListening() {
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
