//
//  ProviderBackend+Ask.swift
//  ErgoServer
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoAsk
import ErgoProtocol
import Foundation
import Logging
import Synchronization

/// One CLI call for Ask: free text as it's written, with Ergo's tools as the only ones it has
extension ProviderBackend {
	/// A CLI can stop to call tools several times, so it gets longer than one stage's single answer
	private static let askTimeout = Duration.seconds(300)

	/// `tools` is the URL this run's tools answer at. `text` hears more of the answer as it's written.
	func ask(prompt: String, tools: String, text: @escaping @Sendable (String) async -> Void) async throws {
		try await RunDirectory.with(in: config.runsDirectory) { run in
			switch credential.provider {
				case .claude:
					try await claudeAsk(prompt: prompt, tools: tools, in: run, text: text)
				case .codex:
					try await codexAsk(prompt: prompt, tools: tools, in: run, text: text)
			}
		}
	}

	// MARK: - Claude Code

	private func claudeAsk(prompt: String, tools: String, in run: RunDirectory, text: @escaping @Sendable (String) async -> Void) async throws {
		guard let executable = config.claudePath else {
			throw ProviderFailure.unavailable("Claude Code isn't installed on the Ergo server")
		}

		let instructions = run.work.appending(path: "instructions.md")
		let toolConfig = run.work.appending(path: "tools.json")
		try run.write(StagePrompts.instructions(for: StageModels.ask), to: instructions)
		try run.write(ClaudeCodeAskCommand.toolConfig(url: tools), to: toolConfig)

		let command = ClaudeCodeAskCommand(
			executable: executable,
			choice: models.choice(for: .claude, stage: StageModels.ask),
			instructions: instructions,
			toolConfig: toolConfig,
			credential: credential,
			run: run
		)

		let stream = AskStreamBox(ClaudeAskStream())
		try await streamAsk(command.command(prompt: prompt), in: run) { line in
			if let more = stream.withLock({ $0.feed(line) }) {
				await text(more)
			}
		}

		guard let line = stream.withLock({ $0.resultLine }), let result = ClaudeCodeResult.decode(line) else {
			throw ProviderFailure.unavailable("Claude Code failed on the Ergo server")
		}
		if let failure = result.failure(kind: credential.kind) {
			throw failure
		}
	}

	// MARK: - Codex

	private func codexAsk(prompt: String, tools: String, in run: RunDirectory, text: @escaping @Sendable (String) async -> Void) async throws {
		guard let executable = config.codexPath else {
			throw ProviderFailure.unavailable("Codex isn't installed on the Ergo server")
		}

		let secret = latest.current
		let command = try CodexCommand(
			executable: executable,
			choice: models.choice(for: .codex, stage: StageModels.ask),
			instructions: StagePrompts.instructions(for: StageModels.ask),
			credential: ProviderCredential(provider: credential.provider, kind: credential.kind, secret: secret),
			run: run,
			tools: tools
		)
		if credential.kind == .subscription {
			try run.write(secret.value, to: command.authFile)
		}

		let stream = AskStreamBox(CodexAskStream())
		let outcome: Result<Void, any Error>
		do {
			try await streamAsk(command.command(prompt: prompt), in: run) { line in
				if let more = stream.withLock({ $0.feed(line) }) {
					await text(more)
				}
			}
			outcome = .success(())
		} catch {
			outcome = .failure(error)
		}

		// Read back however the call ends, since Codex may have rotated the refresh token even if it then failed
		if credential.kind == .subscription {
			await saveRefreshedAuth(from: command.authFile, replacing: secret, in: run)
		}
		try outcome.get()

		let events = CodexEvents(stream.withLock { $0.output })
		if let failure = events.failure {
			throw failure
		}
		guard events.completed else {
			throw ProviderFailure.unavailable("Codex failed on the Ergo server")
		}
	}

	// MARK: - Running

	private func streamAsk(_ command: ProcessRunner.Command, in run: RunDirectory, lines: @escaping @Sendable (String) async -> Void) async throws {
		do {
			_ = try await runner.stream(command, in: run, timeout: Self.askTimeout, lines: lines)
		} catch is ProcessRunner.TimedOut {
			logger.warning("CLI timed out", metadata: ["stage": "\(StageModels.ask)", "provider": "\(credential.provider)"])
			throw ProviderFailure.timedOut("Expected an answer from \(credential.provider.displayName) within \(Self.askTimeout.spelledOut)")
		} catch let error as CancellationError {
			throw error
		} catch let failure as ProviderFailure {
			throw failure
		} catch {
			logger.error("Couldn't run the CLI", metadata: ["stage": "\(StageModels.ask)", "provider": "\(credential.provider)", "error": "\(error)"])
			throw ProviderFailure.unavailable("Couldn't run \(credential.provider.cliName) on the Ergo server")
		}
	}
}

/// Lets a stream parser be fed from the line handler and read once the call's over
private final class AskStreamBox<Stream: Sendable>: Sendable {
	private let stream: Mutex<Stream>

	init(_ stream: Stream) {
		self.stream = Mutex(stream)
	}

	func withLock<Result: Sendable>(_ body: @Sendable (inout Stream) -> Result) -> Result {
		stream.withLock { body(&$0) }
	}
}
