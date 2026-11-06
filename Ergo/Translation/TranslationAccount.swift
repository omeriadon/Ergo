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
	@ObservationIgnored private var connectionsServer: URL?

	// MARK: - connections

	/// Nil until the server has been asked, or it's known there's no account to ask
	private var knownConnections: [Provider: ConnectionStatus]?

	/// Missing means not connected, or not known yet
	var connections: [Provider: ConnectionStatus] {
		knownConnections ?? [:]
	}

	/// Why the last refresh or disconnect failed
	private(set) var problem: String?

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

	// MARK: - connect

	func connect(_ provider: Provider, _ upload: ConnectionUpload) async throws -> ConnectionStatus {
		let server = server
		let status = try await withClient { try await $0.connect(provider, upload) }
		if self.server == server {
			await recordConnection(status)
		}
		return status
	}

	/// Settings won't ask again on its own, so connections that weren't known are asked for now
	private func recordConnection(_ status: ConnectionStatus) async {
		if knownConnections != nil {
			knownConnections?[status.provider] = status
		} else {
			await refresh()
		}
	}

	func disconnect(_ provider: Provider) async {
		guard let server else {
			knownConnections?[provider] = nil
			return
		}
		switch AccountKeychain.lookup(for: server) {
			case .missing:
				knownConnections?[provider] = nil
				return
			case .unavailable:
				problem = Self.keychainUnavailable.message
				return
			case .found:
				break
		}

		do {
			try await withClient { try await $0.disconnect(provider) }
			guard self.server == server else { return }
			knownConnections?[provider] = nil
			problem = nil
		} catch is CancellationError {
		} catch {
			guard self.server == server else { return }
			problem = error.localizedDescription
		}
	}

	/// Runs ChatGPT's device login on the server. `code` is called once with what to enter where.
	func codexDeviceLogin(code: (URL, String) -> Void) async throws -> ConnectionStatus {
		let server = server
		let status = try await withClient { client in
			for try await message in client.codexDeviceLogin() {
				switch message {
					case let .code(url, value):
						code(url, value)
					case let .connected(status):
						return status
					case let .failed(error):
						throw error
				}
			}
			try Task.checkCancellation()
			throw Self.disconnected
		}
		if self.server == server {
			await recordConnection(status)
		}
		return status
	}

	// MARK: - translate

	/// Translates one statement. `descriptors` are the board's six, with an empty string for a slot nobody has named,
	/// so the server reuses a letter for a claim the board already calls something. `events` hears each step as the
	/// server runs it. The server's failures are thrown as `ServiceError`s.
	func translate(english: String, letters: [String], descriptors: [String], events: (TranslationEvent) -> Void) async throws -> Translation {
		let (server, token) = try credentials()
		let request = translateRequest(english: english, letters: letters, descriptors: descriptors)

		return try await signedOutOnUnauthorized(of: server) {
			for try await message in ErgoClient(server: server, token: token).translate(request) {
				switch message {
					case let .event(event):
						events(event)
					case let .finished(translation):
						return translation
					case let .failed(error):
						throw error
				}
			}
			try Task.checkCancellation()
			throw Self.disconnected
		}
	}

	/// Splits pasted English into premises, a conclusion and claims, without writing any logic. The breakdown's
	/// `descriptors` are whatever the caller already names; the board ignores the ones that come back.
	/// `letters` default to the ones the app shows. Events and failures are the same as `translate`'s.
	func breakDown(
		english: String,
		descriptors: [String],
		letters: [String]? = nil,
		events: (TranslationEvent) -> Void
	) async throws -> ArgumentBreakdown {
		let (server, token) = try credentials()
		let request = translateRequest(
			english: english,
			letters: letters ?? LogicLetters.resolved(Defaults[.logicLetters]),
			descriptors: descriptors
		)

		return try await signedOutOnUnauthorized(of: server) {
			for try await message in ErgoClient(server: server, token: token).breakDown(request) {
				switch message {
					case let .event(event):
						events(event)
					case let .finished(breakdown):
						return breakdown
					case let .failed(error):
						throw error
				}
			}
			try Task.checkCancellation()
			throw Self.disconnected
		}
	}

	private func credentials() throws -> (server: URL, token: String) {
		let provider = Defaults[.translationProvider]
		guard let server else {
			throw Self.notSetUp
		}
		switch AccountKeychain.lookup(for: server) {
			case let .found(token):
				return (server, token)
			case .missing:
				throw Self.notConnected(provider)
			case .unavailable:
				throw Self.keychainUnavailable
		}
	}

	/// `scope` is set by the client method that sends it
	private func translateRequest(english: String, letters: [String], descriptors: [String]) -> TranslateRequest {
		TranslateRequest(
			id: UUID(),
			english: english,
			provider: Defaults[.translationProvider],
			letters: letters,
			grammarVersion: LogicGrammar.version,
			// Nothing named yet is the same as not saying
			descriptors: descriptors.allSatisfy(\.isEmpty) ? nil : descriptors
		)
	}

	private func signedOutOnUnauthorized<Result>(of server: URL, _ work: () async throws -> Result) async throws -> Result {
		do {
			return try await work()
		} catch let error as ServiceError where error.code == .unauthorized {
			// The server forgot this account, and a new one has nothing connected
			forgetToken(for: server)
			throw Self.notConnected(Defaults[.translationProvider])
		}
	}

	// MARK: - sign in

	/// Set while this device is signed in, with Apple or an email, on `server`. Sync needs it, translation doesn't.
	private(set) var signedIn: SignedInAccount? {
		didSet {
			Defaults[.signedInAccount] = signedIn
		}
	}

	/// Signed in on the current server, but the Keychain couldn't be read. Sync backs off rather than signing out.
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
	private func forgettingToken(of account: SignedInAccount, _ work: (ErgoClient) async throws -> Void) async throws {
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
	private func adoptServer() {
		guard connectionsServer != server else { return }
		connectionsServer = server
		knownConnections = nil
		problem = nil
		creatingAccount?.task.cancel()
		creatingAccount = nil
	}

	private func forgetToken(for server: URL) {
		AccountKeychain.setToken(nil, for: server)
		knownConnections = nil
		problem = nil
		if signedIn?.server == server {
			signedIn = nil
		}
	}

	// MARK: - account

	@ObservationIgnored
	private var creatingAccount: (server: URL, task: Task<String, Error>)?

	/// Makes an account the first time, and once more if the server no longer knows this one
	private func withClient<Result>(_ work: (ErgoClient) async throws -> Result) async throws -> Result {
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

	private func token(for server: URL) async throws -> String {
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
struct SignedInAccount: Codable, Hashable, Defaults.Serializable {
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
		}
	}
}
