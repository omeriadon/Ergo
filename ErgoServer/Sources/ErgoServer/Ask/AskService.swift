//
//  AskService.swift
//  ErgoServer
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoAsk
import ErgoProtocol
import ErgoTranslation
import Fluent
import Foundation
import Logging
import Synchronization

/// Answers one turn of a conversation with the user's own CLI login. It shares `TranslationService`'s one call at a
/// time per account, since a Codex login can only be used by one call at once.
final class AskService: Sendable {
	let translations: TranslationService
	let runs = AskRuns()
	let tools: AskToolServer<AskTools>

	/// Longest a chat's name can be, since it's shown in a list
	static let titleLimit = 60

	init(translations: TranslationService, tools: AskToolServer<AskTools>) {
		self.translations = translations
		self.tools = tools
	}

	/// Throws a `ServiceError`, or `CancellationError` once the CLI's been stopped. `port` is this server's own, which is
	/// how the CLI on this machine reaches the tools.
	func ask(
		_ request: AskRequest,
		port: Int,
		account: UUID,
		database: any Database,
		logger: Logger,
		send: @escaping AskRuns.Listener
	) async throws {
		if let problem = request.problem {
			throw ServiceError(code: .invalidRequest, message: problem)
		}
		let prompt = try StagePrompts.askMessage(for: request.messages, instructions: request.instructions)
		let answer = Mutex<String>("")

		try await translations.withBackend(provider: request.provider, scope: StageModels.ask, account: account, database: database, logger: logger) { backend in
			let tools = tools
			let responder: AskRuns.Responder = { body in
				await tools.respond(to: body, events: send)
			}
			let token = runs.register(responder)
			defer { runs.remove(token) }

			try await backend.ask(prompt: prompt, tools: "http://127.0.0.1:\(port)/\(ErgoProtocol.Path.askTools)/\(token)", responder: responder) { text in
				answer.withLock { $0 += text }
				await send(.text(text))
			}
		} summary: { _ in
			["messages": "\(request.messages.count)"]
		}

		// Only a chat's first reply is named, since that's when it has no name yet. It's sent before `.finished`, so
		// the app has it by the time the answer ends.
		let reply = answer.withLock { $0 }
		if request.messages.count == 1, let question = request.messages.last?.text, !reply.isEmpty, let title = await chatName(question: question, answer: reply, provider: request.provider, account: account, database: database, logger: logger) {
			await send(.title(title))
		}
	}

	/// Names the chat from its first question and answer. A name is optional, so a failure only means there isn't one.
	private func chatName(
		question: String,
		answer: String,
		provider: Provider,
		account: UUID,
		database: any Database,
		logger: Logger
	) async -> String? {
		do {
			let output = try await translations.withBackend(provider: provider, scope: StageModels.title, account: account, database: database, logger: logger) { backend in
				try await backend.run(TitleStage.self, TitleStage.Input(question: question, answer: answer))
			} summary: { _ in
				[:]
			}
			return Self.cleaned(output.title)
		} catch is CancellationError {
			return nil
		} catch {
			logger.warning("Couldn't name the chat", metadata: ["provider": "\(provider)", "error": "\(error)"])
			return nil
		}
	}

	/// What the model gave, as a line a chat list can show. Nil when nothing's left of it.
	static func cleaned(_ title: String) -> String? {
		let line = title.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
		let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”‘’.")))
		guard !trimmed.isEmpty else { return nil }
		return String(trimmed.prefix(titleLimit))
	}
}
