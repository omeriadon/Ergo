//
//  SyncController+Account.swift
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
	// MARK: - Account

	/// Sign-ins and sign-outs land here, whichever way they happened
	func accountChanged() {
		guard account.signedIn?.withoutEmail != syncingAccount else { return }
		syncingAccount = account.signedIn?.withoutEmail

		stop()
		// Keeps what's merged and pending, so signing in again, to any account, loses nothing
		replica.reset()
		forgetSharedBoards()
		forgetAnalyses()
		saveReplica()
		outcome = nil

		// Before it's ready, `run()` does this once it is
		if isSignedIn, isReady {
			recordAll()
			syncNow()
			startListening()
			registerForPush()
		}
	}

	/// Someone else's boards don't stay behind for whoever signs in next. Boards this account owns stay as ordinary local
	/// ones. Nothing is sent, so this leaves nobody's board: signing back in pulls everything again, these included.
	private func forgetSharedBoards() {
		let departure = BoardShareRecords.departure(from: replica)
		replica.forget(departure.records)
		boardStore.shares = [:]
		boardStore.applyRemote([], deleted: departure.boards)
	}

	/// Annotations and run statuses belong to the account that had them. Boards it owned stay on this device, but what was
	/// written about them goes; the next pull brings back whatever the account signed in now has.
	private func forgetAnalyses() {
		replica.forget(Set(replica.records.values.filter { $0.kind == .annotation || $0.kind == .analysis }.map(\.key)))
		analysis.reset()
		analysis.refresh(from: replica)
	}

	func signIn(identityToken: String, nonce: String, authorizationCode: String? = nil) async throws {
		try await account.signInWithApple(identityToken: identityToken, nonce: nonce, authorizationCode: authorizationCode)
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

	/// Nothing syncs while the account goes, so no request races the token being deleted
	func leaving(_ work: () async throws -> Void) async throws {
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
}
