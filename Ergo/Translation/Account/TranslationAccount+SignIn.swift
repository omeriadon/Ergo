//
//  TranslationAccount+SignIn.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

extension TranslationAccount {
	/// Signed in on the current server, but the Keychain couldn't be read. Sync backs off rather than signing out.
	/// Signed in on the server this device is using now
	var isSignedInHere: Bool {
		signedIn != nil && signedIn?.server == server
	}

	var syncTokenUnavailable: Bool {
		guard let signedIn, signedIn.server == server else { return false }
		if case .unavailable = AccountKeychain.lookup(for: signedIn.server) {
			return true
		}
		return false
	}

	/// Nil unless signed in on the current server
	var syncClient: ErgoClient? {
		guard let signedIn, signedIn.server == server, let token = AccountKeychain.token(for: signedIn.server) else {
			return nil
		}
		return ErgoClient(server: signedIn.server, token: token)
	}

	/// Attaches this device's account to the Apple ID, or joins the account that already has it. Signed in with an
	/// email, it gains a second way in. `nonce` is the raw one; the Apple request carried its hash.
	func signInWithApple(identityToken: String, nonce: String) async throws {
		guard let server else {
			throw Self.noServer
		}

		let reply = try await withClient { try await $0.signInWithApple(identityToken: identityToken, nonce: nonce) }
		AccountKeychain.setToken(reply.token, for: server)
		signedIn = SignedInAccount(server: server, id: reply.accountID, email: signedIn?.email, hasApple: true)

		// Joining another device's account brings its connections
		await refresh()
	}

	/// Attaches an email and password to this device's account. Signed out, the account this device already has becomes
	/// a signed-in one, so there's nothing to merge; signed in with Apple, it gains a second way in.
	func register(email: String, password: String) async throws {
		guard let server else {
			throw Self.noServer
		}

		let email = try AccountEmail.normalized(email)
		try await withClient { try await $0.register(email: email, password: password) }
		// The reply is empty, so a signed-out account's id stays unknown
		signedIn = SignedInAccount(server: server, id: signedIn?.id, email: email, hasApple: signedIn?.hasApple)
	}

	/// Joins the account that has this email, merging this device's account into it on the server.
	/// A wrong email or password is `invalidCredentials`, not `unauthorized`, so it leaves the token alone.
	func logIn(email: String, password: String) async throws {
		guard let server else {
			throw Self.noServer
		}

		let email = try AccountEmail.normalized(email)
		let reply = try await withClient { try await $0.logIn(email: email, password: password) }
		AccountKeychain.setToken(reply.token, for: server)
		signedIn = SignedInAccount(server: server, id: reply.accountID, email: email)

		await refresh()
	}

	/// Signs out every other device of the account. Never through `withClient`, which would make a new account to ask.
	func changePassword(current: String, new: String) async throws {
		guard let signedIn, let client = syncClient else {
			throw Self.notSignedIn
		}

		do {
			try await client.changePassword(current: current, new: new)
		} catch let error as ServiceError where error.code == .unauthorized {
			forgetToken(for: signedIn.server)
			throw error
		}
	}

	/// Forgets only this device's token. The next request makes a new anonymous account.
	func signOut() async throws {
		guard let signedIn else { return }
		try await forgettingToken(of: signedIn) { try await $0.signOut() }
	}

	/// Deletes everything the server keeps for this account, on every device. Data on the devices stays.
	func deleteAccount() async throws {
		guard let signedIn else { return }
		try await forgettingToken(of: signedIn) { try await $0.deleteAccount() }
	}

	/// The server already forgot a token it calls unknown, so that counts as done
	func forgettingToken(of account: SignedInAccount, _ work: (ErgoClient) async throws -> Void) async throws {
		switch AccountKeychain.lookup(for: account.server) {
			case let .found(token):
				do {
					try await work(ErgoClient(server: account.server, token: token))
				} catch let error as ServiceError where error.code == .unauthorized {}
			case .missing:
				break
			case .unavailable:
				// Forgetting now would leave the account on the server with no way back to it
				throw Self.keychainUnavailable
		}
		forgetToken(for: account.server)
	}

	/// Sync says the server doesn't know this token. A new anonymous account gets made when one's needed.
	func forgetToken() {
		guard let server else { return }
		forgetToken(for: server)
	}

	/// Sync says this account isn't signed in. Translation keeps using it.
	func forgetSignIn() {
		signedIn = nil
	}

	/// Called when `serverEnvironment` or the Mac's address changed. A sign-in belongs to the server it was made on,
	/// so switching signs out here, and signing in again the same way reaches the same account.
	/// Each server keeps its own token in the Keychain, so switching back finds the old account's token.
	func serverChanged() {
		adoptServer()
		if let signedIn, signedIn.server != server {
			self.signedIn = nil
		}
	}

	/// Connections are another server's once it's switched, so they're dropped until asked for again
	func adoptServer() {
		guard connectionsServer != server else { return }
		connectionsServer = server
		knownConnections = nil
		problem = nil
		creatingAccount?.task.cancel()
		creatingAccount = nil
	}

	func forgetToken(for server: URL) {
		AccountKeychain.setToken(nil, for: server)
		knownConnections = nil
		problem = nil
		if signedIn?.server == server {
			signedIn = nil
		}
	}
}
