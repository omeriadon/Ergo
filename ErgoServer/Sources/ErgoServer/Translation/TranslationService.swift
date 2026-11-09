//
//  TranslationService.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Fluent
import Foundation
import Logging
import Synchronization

/// Runs translations, one at a time per account. Codex spends its refresh token as it uses it, so two calls
/// with one login at once could leave the stored copy already spent. Connection checks go through here too.
final class TranslationService: Sendable {
	let vault: CredentialVault
	let config: ServerConfig
	let runner: ProcessRunner
	private let running = Mutex<Set<UUID>>([])

	init(vault: CredentialVault, config: ServerConfig, runner: ProcessRunner) {
		self.vault = vault
		self.config = config
		self.runner = runner
	}

	// MARK: - Single flight

	/// Throws `.busy` straight away when the account already has something running
	func exclusive<T>(for account: UUID, _ body: () async throws -> T) async throws -> T {
		guard running.withLock({ $0.insert(account).inserted }) else {
			throw ServiceError(code: .busy, message: "Expected one translation at a time, another one is still running")
		}
		defer { running.withLock { _ = $0.remove(account) } }
		return try await body()
	}

	// MARK: - Translating

	/// Throws a `ServiceError`, or `CancellationError` once the CLI's been stopped. English that isn't worth a model call
	/// comes back as a translation with that issue, the same as the pipeline would give.
	func translate(
		_ request: TranslateRequest,
		account: UUID,
		database: any Database,
		logger: Logger,
		events: @escaping @Sendable (TranslationEvent) async -> Void
	) async throws -> Translation {
		try check(request)
		if let problem = EnglishValidator.problem(with: request.english) {
			return Translation(english: request.english, issues: [TranslationIssue(severity: .error, message: problem)])
		}

		return try await withBackend(provider: request.provider, scope: request.scope.rawValue, account: account, database: database, logger: logger) { backend in
			try await pipeline(for: request, backend: backend).translate(request.english, events: events)
		} summary: { translation in
			["issues": "\(translation.issues.count)"]
		}
	}

	/// The same checks and rules as `translate`, for a pasted argument: only the gate and breakdown run
	func breakDown(
		_ request: TranslateRequest,
		account: UUID,
		database: any Database,
		logger: Logger,
		events: @escaping @Sendable (TranslationEvent) async -> Void
	) async throws -> ArgumentBreakdown {
		try check(request)
		if let problem = EnglishValidator.problem(with: request.english) {
			return ArgumentBreakdown(
				kind: .neither,
				descriptors: LogicLetters.slots.map { LogicLetters.descriptor(for: $0, in: request.descriptors ?? []) },
				issues: [TranslationIssue(severity: .error, message: problem)]
			)
		}

		return try await withBackend(provider: request.provider, scope: request.scope.rawValue, account: account, database: database, logger: logger) { backend in
			try await pipeline(for: request, backend: backend).breakDown(request.english, events: events)
		} summary: { breakdown in
			["premises": "\(breakdown.premises.count)", "issues": "\(breakdown.issues.count)"]
		}
	}

	private func pipeline(for request: TranslateRequest, backend: ProviderBackend) -> TranslationPipeline {
		TranslationPipeline(backend: backend, letters: request.letters, descriptors: request.descriptors)
	}

	/// What no model call is needed to refuse: another grammar, letters or descriptors the app would never send
	private func check(_ request: TranslateRequest) throws {
		guard request.grammarVersion == LogicGrammar.version else {
			throw ServiceError(code: .outdatedApp, message: "Expected logic grammar \(LogicGrammar.version), found \(request.grammarVersion), update the app")
		}
		guard LogicLetters.resolved(request.letters) == request.letters else {
			throw ServiceError(code: .invalidRequest, message: "Expected six distinct letters, found '\(request.letters.joined(separator: " "))'")
		}
		if let descriptors = request.descriptors {
			guard descriptors.count <= LogicLetters.slots.count else {
				throw ServiceError(code: .invalidRequest, message: "Expected at most \(LogicLetters.slots.count) descriptors, found \(descriptors.count)")
			}
			if let long = descriptors.first(where: { $0.count > LogicLetters.descriptorLengthLimit }) {
				throw ServiceError(
					code: .invalidRequest,
					message: "Expected descriptors of at most \(LogicLetters.descriptorLengthLimit) characters, found \(long.count)"
				)
			}
		}
	}

	/// Opens the user's connection, runs `work` with it, one at a time per account, and turns whatever goes wrong into
	/// a `ServiceError`. `summary` is what's worth logging about the result, never its text. `exclusive` is false for a
	/// Claude Code login, which has nothing to spend, when the call shouldn't make everything else wait.
	func withBackend<Result: Sendable>(
		provider: Provider,
		scope: String,
		account: UUID,
		database: any Database,
		logger: Logger,
		exclusive isExclusive: Bool = true,
		_ work: (ProviderBackend) async throws -> Result,
		summary: (Result) -> Logger.Metadata
	) async throws -> Result {
		// A server-managed provider uses the server's own key, so there's no row to find, mark or reseal
		let id: UUID?
		let credential: ProviderCredential
		if provider.isServerManaged {
			guard let openRouter = config.openRouter else {
				throw ServiceError(code: .notConnected, message: "\(provider.displayName) isn't set up on the Ergo server")
			}
			id = nil
			credential = ProviderCredential(provider: provider, kind: .apiKey, secret: openRouter.key)
		} else {
			guard let stored = try await Credential.find(provider, for: account, on: database), let storedID = stored.id else {
				throw ServiceError(code: .notConnected, message: "\(provider.displayName) isn't connected")
			}
			id = storedID
			do {
				credential = try ProviderCredential(
					provider: stored.provider,
					kind: stored.kind,
					secret: vault.open(stored.sealed, account: account, provider: stored.provider)
				)
			} catch {
				logger.error("Couldn't unseal a credential", metadata: ["provider": "\(provider)"])
				throw ServiceError(code: .notConnected, message: "Couldn't read the saved \(provider.displayName) connection, connect it again")
			}
		}

		func run() async throws -> Result {
			let backend = ProviderBackend(credential: credential, config: config, runner: runner, logger: logger) { [vault] refreshed in
				guard let id else { return }
				do {
					try await Credential.reseal(id, with: vault.seal(refreshed, account: account, provider: credential.provider), on: database)
				} catch {
					logger.error("Couldn't save a refreshed login", metadata: ["provider": "\(credential.provider)"])
				}
			}

			let start = ContinuousClock.now
			do {
				let result = try await work(backend)
				if let id {
					try? await Credential.markWorking(id, on: database)
				}
				var metadata: Logger.Metadata = [
					"provider": "\(credential.provider)",
					"scope": "\(scope)",
					"duration": "\(start.duration(to: .now))",
				]
				metadata.merge(summary(result)) { first, _ in first }
				logger.info("Translated", metadata: metadata)
				return result
			} catch let failure as ProviderFailure {
				if let id, case let .credentialRejected(problem) = failure {
					try? await Credential.mark(id, problem: problem, on: database)
				}
				logger.warning("Translation failed", metadata: ["provider": "\(credential.provider)", "code": "\(failure.serviceError.code)"])
				throw failure.serviceError
			} catch let error as CancellationError {
				logger.info("Translation cancelled", metadata: ["provider": "\(credential.provider)"])
				throw error
			} catch {
				logger.error("Translation failed", metadata: ["provider": "\(credential.provider)", "error": "\(String(reflecting: error))"])
				throw ServiceError.internalFailure
			}
		}

		guard isExclusive else {
			return try await run()
		}
		return try await exclusive(for: account, run)
	}
}
