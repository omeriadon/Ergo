//
//  TranslationAccount.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

/// This install's account on the Ergo server, and which providers it has connected.
/// The account is only made when something first needs it, so setting a server costs nothing.
///
/// Signing in, with Apple or an email, keeps one account token per server, so translation and sync share it.
@MainActor
@Observable
final class TranslationAccount {
	init() {
		signedIn = Defaults[.signedInAccount]
		connectionsServer = ServerEnvironment.current
	}

	/// For previews
	init(signedIn: SignedInAccount?) {
		self.signedIn = signedIn
		connectionsServer = ServerEnvironment.current
	}

	// MARK: - server

	/// Read fresh each time, so it follows both `serverEnvironment` and the Mac's address
	var server: URL? {
		ServerEnvironment.current
	}

	/// The server `connections` came from, so a switch drops them
	@ObservationIgnored var connectionsServer: URL?

	// MARK: - connections

	/// Nil until the server has been asked, or it's known there's no account to ask
	var knownConnections: [Provider: ConnectionStatus]?

	/// Missing means not connected, or not known yet
	var connections: [Provider: ConnectionStatus] {
		knownConnections ?? [:]
	}

	/// Why the last refresh or disconnect failed
	var problem: String?

	/// How much of Ergo's model this account has left, and what it's paid for. Nil until the server's been asked.
	var usage: UsageStatus?

	/// Whether `provider` has a connection on the current server. Nil until that's known, since asking costs a request.
	func isConnected(_ provider: Provider) -> Bool? {
		guard let server else { return nil }
		switch AccountKeychain.lookup(for: server) {
			case .missing:
				return false
			case .unavailable:
				return nil
			case .found:
				return knownConnections.map { $0[provider] != nil }
		}
	}

	func refresh() async {
		adoptServer()
		guard let server else {
			knownConnections = nil
			problem = nil
			return
		}
		switch AccountKeychain.lookup(for: server) {
			case .missing:
				// No account yet, so nothing can be connected
				knownConnections = [:]
				problem = nil
				return
			case .unavailable:
				// Can't tell, so what was known stays as it was
				problem = Self.keychainUnavailable.message
				return
			case .found:
				break
		}

		do {
			let statuses = try await withClient { try await $0.connections() }
			// The server was switched while asking, so this is the old one's answer
			guard self.server == server else { return }
			knownConnections = Dictionary(statuses.map { ($0.provider, $0) }) { _, last in last }
			problem = nil
		} catch is CancellationError {
		} catch {
			guard self.server == server else { return }
			problem = error.localizedDescription
		}
	}

	// MARK: - sign in

	/// Set while this device is signed in, with Apple or an email, on `server`. Sync and Ask need it, translation doesn't.
	var signedIn: SignedInAccount? {
		didSet {
			Defaults[.signedInAccount] = signedIn
		}
	}

	// MARK: - account

	@ObservationIgnored
	var creatingAccount: (server: URL, task: Task<String, any Error>)?

	/// Makes an account the first time, and once more if the server no longer knows this one
	func withClient<Result>(_ work: (ErgoClient) async throws -> Result) async throws -> Result {
		guard let server else {
			throw Self.notSetUp
		}

		do {
			return try await work(ErgoClient(server: server, token: token(for: server)))
		} catch let error as ServiceError where error.code == .unauthorized {
			forgetToken(for: server)
			return try await work(ErgoClient(server: server, token: token(for: server)))
		}
	}

	func token(for server: URL) async throws -> String {
		switch AccountKeychain.lookup(for: server) {
			case let .found(token):
				return token
			case .missing:
				break
			case .unavailable:
				// Making an account now would strand the one this token belongs to
				throw Self.keychainUnavailable
		}
		// Two calls at once share one account, if they're for the same server
		if let creatingAccount, creatingAccount.server == server {
			return try await creatingAccount.task.value
		}

		let creating = Task {
			try await ErgoClient(server: server, token: nil).createAccount().token
		}
		creatingAccount = (server, creating)
		defer {
			// Only its own, since a switch may have started another
			if creatingAccount?.server == server {
				creatingAccount = nil
			}
		}

		let token = try await creating.value
		AccountKeychain.setToken(token, for: server)
		return token
	}

	// MARK: - errors

	static let notSetUp = ServiceError(code: .notConnected, message: "Translation isn't set up")
	static let noServer = ServiceError(code: .notConnected, message: "Expected a server, set one in Translation")
	static let notSignedIn = ServiceError(code: .signInRequired, message: "Expected to be signed in, sign in first")
	static let keychainUnavailable = ServiceError(code: .internalError, message: "Couldn't read the account token from the Keychain")
	static let disconnected = ServiceError(code: .providerUnavailable, message: "Lost connection to the Ergo server")

	static func notConnected(_ provider: Provider) -> ServiceError {
		ServiceError(code: .notConnected, message: "\(provider.name) isn't connected")
	}
}

// MARK: - SignedInAccount

/// Which account this device signed in to, and on which server
nonisolated struct SignedInAccount: Codable, Hashable, Defaults.Serializable {
	var server: URL

	/// Nil after registering an email while signed out, since that reply doesn't say. Only ever compared.
	var id: UUID?

	/// Only for showing, and only known when this device signed in or registered with it.
	/// Set means the account has an email, so its password can be changed.
	var email: String?

	/// True once this device has used Sign in with Apple. Nil says nothing: another device may have added it.
	var hasApple: Bool?

	/// The email is only shown, so gaining one isn't a change of account
	var withoutEmail: SignedInAccount {
		SignedInAccount(server: server, id: id)
	}
}

// MARK: - Provider

extension Provider {
	var name: String {
		switch self {
			case .claude:
				"Claude"
			case .codex:
				"ChatGPT"
			case .openrouter:
				"Ergo's model"
		}
	}
}
