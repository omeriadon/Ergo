//
//  AskCLIStreams.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

/// Reads the answer out of `claude -p --output-format stream-json --include-partial-messages`, a JSON object per line.
/// Lines that aren't JSON, like anything on stderr, are skipped.
public struct ClaudeAskStream: Sendable {
	private struct Line: Decodable {
		struct Event: Decodable {
			struct Delta: Decodable {
				let type: String?
				let text: String?
			}

			struct Block: Decodable {
				let type: String?
			}

			let type: String?
			let delta: Delta?
			let contentBlock: Block?

			enum CodingKeys: String, CodingKey {
				case type, delta
				case contentBlock = "content_block"
			}
		}

		let type: String?
		let event: Event?
		let result: String?
	}

	private var hasText = false
	private var startsNewBlock = false

	/// The last `result` line as it came, which says how the run ended
	public private(set) var resultLine: Data?

	public init() {}

	/// More of the answer, if this line has any
	public mutating func feed(_ line: String) -> String? {
		let data = Data(line.utf8)
		guard let decoded = try? JSONDecoder().decode(Line.self, from: data) else { return nil }

		switch decoded.type {
			case "stream_event":
				switch decoded.event?.type {
					case "content_block_start":
						if decoded.event?.contentBlock?.type == "text" {
							startsNewBlock = true
						}
					case "content_block_delta":
						guard decoded.event?.delta?.type == "text_delta", let text = decoded.event?.delta?.text, !text.isEmpty else { return nil }
						return added(text)
					default:
						break
				}
			case "result":
				resultLine = data
				// Only when nothing streamed, since this repeats the last message
				if !hasText, let result = decoded.result, !result.isEmpty {
					return added(result)
				}
			default:
				break
		}
		return nil
	}

	private mutating func added(_ text: String) -> String {
		// Text before and after a tool call are separate blocks that would otherwise run together
		let separator = hasText && startsNewBlock ? "\n\n" : ""
		hasText = true
		startsNewBlock = false
		return separator + text
	}
}

/// Reads the answer out of `codex exec --json`, which reports each message whole once it's finished
public struct CodexAskStream: Sendable {
	private struct Line: Decodable {
		struct Item: Decodable {
			let type: String?
			let text: String?
		}

		let type: String?
		let item: Item?
	}

	private var hasText = false

	/// Every line, for `CodexEvents` to find out how the run ended
	public private(set) var output = Data()

	public init() {}

	public mutating func feed(_ line: String) -> String? {
		output.append(Data(line.utf8))
		output.append(UInt8(ascii: "\n"))

		guard
			let decoded = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)),
			decoded.type == "item.completed",
			decoded.item?.type == "agent_message",
			let text = decoded.item?.text,
			!text.isEmpty
		else {
			return nil
		}
		defer { hasText = true }
		return hasText ? "\n\n" + text : text
	}
}
