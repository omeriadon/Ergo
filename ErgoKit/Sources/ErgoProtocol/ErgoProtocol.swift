//
//  ErgoProtocol.swift
//  ErgoKit
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation

/// How the app and the Ergo server talk.
///
/// REST sends `versionHeader` on every request, and `Authorization: Bearer <token>` on all but `Path.accounts` and
/// `Path.invitePreview`. Errors come back as a non-2xx status with a `ServiceError` body.
///
/// The translate socket gets exactly one `TranslateClientMessage.translate`, answers with any number of `.event`s,
/// then exactly one `.finished` or `.failed`, and closes. Sending `.cancel` or closing stops the work.
/// `TranslateRequest.scope` picks the answer's type: `.statement` gets `TranslateServerMessage`s, `.argument` gets
/// `BreakDownServerMessage`s. Failures before the scope is known, like a missing request, use the first.
///
/// The ask socket gets exactly one `AskClientMessage.ask`, answers with any number of `.text`, `.tool` and `.action`
/// messages, then exactly one `.finished` or `.failed`, and closes. Sending `.cancel` or closing stops the work.
/// A message type this version doesn't know decodes to `.unknown`, so adding one needs no new protocol version.
///
/// The device login socket sends `.code` once, then `.connected` or `.failed`, and closes. Closing it cancels the login.
///
/// Sync needs an account signed in with Apple or an email and password. The sync socket only ever sends `SyncLiveMessage`s and stays open
/// until either end closes it; the server pings it every 20 s.
///
/// A shared board's records are copied by the server into every member's account, so a member hears about them through
/// their own sync and socket, with their own cursor. Who's on a board arrives the same way, as `share` records only the
/// server writes. A push to a board the account may not edit doesn't fail the request: it comes back in
/// `SyncResponse.rejected`. Invite tokens go in bodies, never in API paths, so they can't land in logs.
public enum ErgoProtocol {
	public static let version = 1
	public static let versionHeader = "Ergo-Protocol-Version"

	public enum Path {
		/// POST → `AccountCreated`, no auth
		public static let accounts = "v1/accounts"

		/// DELETE
		public static let account = "v1/account"

		/// POST `SignInWithAppleRequest` → `SignedIn`
		public static let appleSignIn = "v1/account/apple"

		/// DELETE signs out this device only
		public static let accountToken = "v1/account/token"

		/// POST `EmailCredentials` → 204. Attaches an email and password to this device's account.
		public static let register = "v1/account/register"

		/// POST `EmailCredentials` → `SignedIn`. Joins the account that owns the email.
		public static let logIn = "v1/account/login"

		/// POST `ChangePasswordRequest` → 204. Signs out every other device.
		public static let password = "v1/account/password"

		/// GET → `[ConnectionStatus]`. PUT `ConnectionUpload` → `ConnectionStatus`, or DELETE, at `v1/connections/<provider>`.
		public static let connections = "v1/connections"

		/// WebSocket of `DeviceLoginMessage`
		public static let deviceLogin = "v1/connections/codex/device-login"

		/// WebSocket of `TranslateClientMessage` and `TranslateServerMessage` (or `BreakDownServerMessage`)
		public static let translate = "v1/translate"

		/// WebSocket of `AskClientMessage` and `AskServerMessage`. Needs a signed-in account.
		public static let ask = "v1/ask"

		/// POST of one MCP JSON-RPC message, from the CLI answering an ask. `<token>` is the run's, there's no other auth.
		public static let askTools = "v1/ask/tools"

		/// POST `SyncRequest` → `SyncResponse`
		public static let sync = "v1/sync"

		/// WebSocket of `SyncLiveMessage`
		public static let syncLive = "v1/sync/live"
	}

	// MARK: - Coding

	/// Dates are ISO 8601 on both ends, so always code with these
	public static var encoder: JSONEncoder {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return encoder
	}

	public static var decoder: JSONDecoder {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return decoder
	}
}
