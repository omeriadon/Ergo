//
//  ProviderBackend+OpenRouter.swift
//  ErgoServer
//
//  Created by Adon Omeri on 9/11/2026.
//

import ErgoTranslation
import Foundation
import Logging

/// OpenRouter has no CLI, so the server talks to it directly with its own key and model. A stage is one call that has to
/// match the stage's schema. Ask and board analysis loop: the model calls Ergo's tools, and the server answers them in
/// process, by handing the same JSON-RPC the CLIs send to the run's responder.
extension ProviderBackend {
	private func openRouterClient() throws -> (client: OpenRouterClient, model: String) {
		guard let openRouter = config.openRouter else {
			throw ProviderFailure.unavailable("\(Provider.openrouter.displayName) isn't set up on the Ergo server")
		}
		return (OpenRouterClient(key: openRouter.key, logger: logger), openRouter.model)
	}

	// MARK: - Stages

	func openRouter<Stage: TranslationStage>(_: Stage.Type, prompt: String) async throws -> Stage.Output? {
		let (client, model) = try openRouterClient()
		let schema = try JSONSerialization.jsonObject(with: Data(Stage.outputSchema.encoded().utf8))
		let instructions = try StagePrompts.instructions(for: Stage.name)

		let body = try JSONSerialization.data(withJSONObject: [
			"model": model,
			"stream": true,
			"messages": [
				["role": "system", "content": instructions],
				["role": "user", "content": prompt],
			],
			"response_format": [
				"type": "json_schema",
				"json_schema": ["name": Stage.name, "strict": true, "schema": schema],
			],
			// Only models that honour the schema, instead of one that quietly ignores it
			"provider": ["require_parameters": true],
		] as [String: Any])

		let start = ContinuousClock.now
		let completion = try await client.complete(body, timeout: runner.timeout) { _ in }
		log(Stage.name, completion, since: start)

		return try? JSONDecoder().decode(Stage.Output.self, from: Data(Self.unfenced(completion.text).utf8))
	}

	/// Some models wrap JSON in a code fence however they're asked
	private static func unfenced(_ text: String) -> String {
		var answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard answer.hasPrefix("```") else { return answer }
		answer = String(answer.drop { $0 != "\n" }.dropFirst())
		if answer.hasSuffix("```") {
			answer.removeLast(3)
		}
		return answer.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	// MARK: - Ask

	func openRouterAsk(prompt: String, settings: AskRunSettings, responder: @escaping AskRuns.Responder, text: @escaping @Sendable (String) async -> Void) async throws {
		let (client, model) = try openRouterClient()
		let tools = try await openRouterTools(settings, responder: responder)
		let instructions = try StagePrompts.instructions(for: settings.instructions)

		var messages: [[String: Any]] = [
			["role": "system", "content": instructions],
			["role": "user", "content": prompt],
		]
		let deadline = ContinuousClock.now + settings.timeout

		for _ in 0 ..< settings.maxTurns {
			let remaining = ContinuousClock.now.duration(to: deadline)
			guard remaining > .zero else {
				throw ProviderFailure.timedOut("Expected an answer from \(Provider.openrouter.displayName) within \(settings.timeout.spelledOut)")
			}

			let body = try JSONSerialization.data(withJSONObject: [
				"model": model,
				"stream": true,
				"messages": messages,
				"tools": tools,
				"provider": ["require_parameters": true],
			] as [String: Any])

			let start = ContinuousClock.now
			let completion = try await client.complete(body, timeout: remaining, text: text)
			log(StageModels.ask, completion, since: start)

			guard !completion.toolCalls.isEmpty else {
				guard completion.finishReason != "length" else {
					throw ProviderFailure.unavailable("The answer from \(Provider.openrouter.displayName) was cut off")
				}
				guard !completion.text.isEmpty else {
					throw ProviderFailure.unavailable("\(Provider.openrouter.displayName) didn't answer")
				}
				return
			}

			messages.append([
				"role": "assistant",
				"content": completion.text,
				"tool_calls": completion.toolCalls.map { call in
					["id": call.id, "type": "function", "function": ["name": call.name, "arguments": call.arguments]] as [String: Any]
				},
			])
			for call in completion.toolCalls {
				try await messages.append([
					"role": "tool",
					"tool_call_id": call.id,
					"content": openRouterToolResult(call, responder: responder),
				])
			}
		}
		throw ProviderFailure.unavailable("\(Provider.openrouter.displayName) kept calling tools without answering")
	}

	/// What the run's tools are, from the same `tools/list` a CLI would ask, in OpenAI's shape
	private func openRouterTools(_ settings: AskRunSettings, responder: AskRuns.Responder) async throws -> [[String: Any]] {
		let reply = await responder(Self.rpc("tools/list", id: 1))
		guard
			let result = (try? JSONSerialization.jsonObject(with: reply)) as? [String: Any],
			let list = (result["result"] as? [String: Any])?["tools"] as? [[String: Any]]
		else {
			throw ProviderFailure.unavailable("Couldn't read Ergo's tools on the Ergo server")
		}

		return list.compactMap { tool in
			guard let name = tool["name"] as? String, settings.toolNames.contains(name) else { return nil }
			return [
				"type": "function",
				"function": [
					"name": name,
					"description": tool["description"] as? String ?? "",
					"parameters": tool["inputSchema"] ?? ["type": "object", "properties": [String: Any]()],
				] as [String: Any],
			]
		}
	}

	/// Whatever the tool said, an error included, since the model reads it and can put it right
	private func openRouterToolResult(_ call: OpenRouterClient.ToolCall, responder: AskRuns.Responder) async throws -> String {
		let arguments: Any = call.arguments.isEmpty ? [String: Any]() : (try? JSONSerialization.jsonObject(with: Data(call.arguments.utf8))) ?? NSNull()
		guard arguments is [String: Any] else {
			return "Expected the arguments as a JSON object"
		}

		let reply = await responder(Self.rpc("tools/call", id: 2, params: ["name": call.name, "arguments": arguments]))
		guard let message = (try? JSONSerialization.jsonObject(with: reply)) as? [String: Any] else {
			return "The tool gave no answer"
		}
		if let error = message["error"] as? [String: Any] {
			return error["message"] as? String ?? "The tool failed"
		}
		let content = (message["result"] as? [String: Any])?["content"] as? [[String: Any]]
		return content?.compactMap { $0["text"] as? String }.joined(separator: "\n") ?? ""
	}

	private static func rpc(_ method: String, id: Int, params: [String: Any] = [:]) -> Data {
		let message: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
		return (try? JSONSerialization.data(withJSONObject: message)) ?? Data()
	}

	// MARK: - Logging

	/// Never the text, which is the user's conversation
	private func log(_ stage: String, _ completion: OpenRouterClient.Completion, since start: ContinuousClock.Instant) {
		var metadata: Logger.Metadata = [
			"stage": "\(stage)",
			"provider": "\(credential.provider)",
			"duration": "\(start.duration(to: .now))",
			"finish": "\(completion.finishReason ?? "none")",
		]
		if let usage = completion.usage {
			metadata["input_tokens"] = "\(usage.promptTokens.map(String.init) ?? "none")"
			metadata["output_tokens"] = "\(usage.completionTokens.map(String.init) ?? "none")"
		}
		logger.info("OpenRouter call", metadata: metadata)
	}
}
