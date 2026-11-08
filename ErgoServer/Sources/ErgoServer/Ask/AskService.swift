//
//  AskService.swift
//  ErgoServer
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoAsk
import ErgoProtocol
import Fluent
import Foundation
import Logging

/// Answers one turn of a conversation with the user's own CLI login. It shares `TranslationService`'s one call at a
/// time per account, since a Codex login can only be used by one call at once.
final class AskService: Sendable {
	let translations: TranslationService
	let runs = AskRuns()
	let tools: AskToolServer<AskTools>

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

		try await translations.withBackend(provider: request.provider, scope: StageModels.ask, account: account, database: database, logger: logger) { backend in
			let tools = tools
			let token = runs.register { body in
				await tools.respond(to: body, events: send)
			}
			defer { runs.remove(token) }

			try await backend.ask(prompt: prompt, tools: "http://127.0.0.1:\(port)/\(ErgoProtocol.Path.askTools)/\(token)") { text in
				await send(.text(text))
			}
		} summary: { _ in
			["messages": "\(request.messages.count)"]
		}
	}
}
