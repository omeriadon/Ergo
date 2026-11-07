//
//  ErgoClient+Sharing.swift
//  ErgoKit
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

public extension ErgoClient {
	// MARK: - Sharing a board

	/// Makes a link anyone can join with. The first one shares the board, which must already be synced.
	func createBoardInvite(board: String, _ body: CreateBoardInvite) async throws -> BoardInvite {
		try await send(request("POST", ErgoProtocol.Path.boardInvites(board), body: body))
	}

	/// Every open link stops working. People who already joined stay.
	func revokeBoardInvites(board: String) async throws {
		_ = try await data(for: request("DELETE", ErgoProtocol.Path.boardInvites(board)))
	}

	func updateBoardMember(board: String, member: UUID, role: BoardRole) async throws {
		let body = UpdateBoardMember(role: role)
		_ = try await data(for: request("POST", ErgoProtocol.Path.boardMember(board, member.uuidString), body: body))
	}

	func removeBoardMember(board: String, member: UUID) async throws {
		_ = try await data(for: request("DELETE", ErgoProtocol.Path.boardMember(board, member.uuidString)))
	}

	/// Everyone else loses the board, and the owner keeps it
	func stopSharingBoard(board: String) async throws {
		_ = try await data(for: request("DELETE", ErgoProtocol.Path.boardShare(board)))
	}

	// MARK: - Joining

	/// Sends no bearer token, since someone can open a link before they have an account
	func previewBoardInvite(token: String) async throws -> BoardInvitePreview {
		try await send(request("POST", ErgoProtocol.Path.invitePreview, authorized: false, body: BoardInviteToken(token: token)))
	}

	func acceptBoardInvite(token: String, name: String) async throws -> JoinedBoard {
		try await send(request("POST", ErgoProtocol.Path.inviteAccept, body: AcceptBoardInvite(token: token, name: name)))
	}

	// MARK: - Push

	func registerPushDevice(token: String, environment: PushEnvironment) async throws {
		let body = PushDevice(token: token, environment: environment)
		_ = try await data(for: request("PUT", ErgoProtocol.Path.pushDevice, body: body))
	}

	/// Forgets only this device's push token
	func unregisterPushDevice() async throws {
		_ = try await data(for: request("DELETE", ErgoProtocol.Path.pushDevice))
	}
}
