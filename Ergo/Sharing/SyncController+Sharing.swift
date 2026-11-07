//
//  SyncController+Sharing.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoClient
import ErgoProtocol
import Foundation
import UIKit
import UserNotifications

/// The routes behind sharing a board. Who's on a board comes back through sync as a `share` record, so each of these only
/// has to ask for a sync afterwards.
extension SyncController {
	// MARK: - Owning a board

	/// Makes a link. The first one shares the board, which the server has to have by then.
	func invite(to board: Board.ID, role: BoardRole, title: String, name: String) async throws -> BoardInvite {
		if boardStore.shares[board] == nil {
			try await syncAndWait()
		}
		let body = CreateBoardInvite(role: role, title: String(title.prefix(200)), name: SharingName.cleaned(name))
		let invite = try await withSyncClient { try await $0.createBoardInvite(board: BoardRecord.id(board), body) }
		syncNow()
		return invite
	}

	func updateMember(_ member: UUID, of board: Board.ID, role: BoardRole) async throws {
		try await withSyncClient { try await $0.updateBoardMember(board: BoardRecord.id(board), member: member, role: role) }
		syncNow()
	}

	func removeMember(_ member: UUID, from board: Board.ID) async throws {
		try await withSyncClient { try await $0.removeBoardMember(board: BoardRecord.id(board), member: member) }
		syncNow()
	}

	func revokeInvites(for board: Board.ID) async throws {
		try await withSyncClient { try await $0.revokeBoardInvites(board: BoardRecord.id(board)) }
	}

	func stopSharing(_ board: Board.ID) async throws {
		try await withSyncClient { try await $0.stopSharingBoard(board: BoardRecord.id(board)) }
		syncNow()
	}

	// MARK: - Joining

	/// Asks without an account, since someone can open a link before they have one
	func previewInvite(token: String) async throws -> BoardInvitePreview {
		guard let server = account.server else {
			throw TranslationAccount.noServer
		}
		return try await ErgoClient(server: server, token: nil).previewBoardInvite(token: token)
	}

	/// Joins, syncs so the board is here, and opens it
	func join(token: String, name: String) async throws {
		let joined = try await withSyncClient { try await $0.acceptBoardInvite(token: token, name: SharingName.cleaned(name)) }
		try? await syncAndWait()

		guard let id = UUID(uuidString: joined.board), boardStore.boards.contains(where: { $0.id == id }) else {
			throw ServiceError(code: .internalError, message: "Expected the board after joining, found it hasn't synced yet. It'll be in Boards once it has.")
		}
		boardStore.open(id)
	}

	// MARK: - Push

	/// Silent pushes need no permission, so this happens as soon as someone's signed in
	func registerForPush() {
		guard isSignedIn else { return }
		UIApplication.shared.registerForRemoteNotifications()
	}

	/// iOS hands the token over on every launch, so a failed upload gets another go on the next one
	func uploadPushToken(_ token: Data) {
		let hex = token.map { String(format: "%02x", $0) }.joined()
		#if DEBUG
			let environment = PushEnvironment.sandbox
		#else
			let environment = PushEnvironment.production
		#endif
		Task {
			try? await withSyncClient { try await $0.registerPushDevice(token: hex, environment: environment) }
		}
	}

	/// Only ever called once someone has shared or joined a board, when "someone edited your board" makes sense.
	/// iOS only shows the question the first time.
	func askToNotify() {
		Task {
			_ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
		}
	}

	// MARK: - Client

	/// The server forgetting this token means the same here as it does when syncing
	@discardableResult
	private func withSyncClient<Result>(_ work: (ErgoClient) async throws -> Result) async throws -> Result {
		guard let client = account.syncClient else {
			throw TranslationAccount.notSignedIn
		}
		do {
			return try await work(client)
		} catch let error as ServiceError where error.code == .unauthorized {
			account.forgetToken()
			accountChanged()
			throw error
		}
	}
}
