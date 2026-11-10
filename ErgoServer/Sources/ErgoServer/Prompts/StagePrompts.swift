//
//  StagePrompts.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Foundation

/// What each stage's model is told. The instructions live in `Prompts/<Feature>/<stage>.md`, the input travels as JSON,
/// so the user's English only ever reaches a model as a JSON string inside data, never in an instruction.
enum StagePrompts {
	struct Missing: Error, CustomStringConvertible {
		let stage: String

		var description: String {
			"Missing instrucfftions for the '\(stage)' stage"
		}
	}

	private static let names = StageModels.stages + [StageModels.ask, StageModels.analyse, StageModels.title]

	private static let all: [String: String] = Dictionary(uniqueKeysWithValues: names.compactMap { stage in
		Bundle.module.url(forResource: stage, withExtension: "md")
			.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
			.map { (stage, $0) }
	})

	/// Checked at launch, so a broken bundle never gets as far as a translation
	static var missing: [String] {
		names.filter { all[$0] == nil }
	}

	static func instructions(for stage: String) throws -> String {
		guard let instructions = all[stage] else {
			throw Missing(stage: stage)
		}
		return instructions
	}

	/// The conversation as data too, so what's pasted into it can't pass for an instruction
	static func askMessage(for messages: [AskRequestMessage], instructions: String? = nil) throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
		let json = try String(decoding: encoder.encode(messages), as: UTF8.self)

		return """
		The conversation so far:

		```json
		\(json)
		```

		Answer the last message. Search and read the library first, and only say what the entries you read this turn say. Your own knowledge isn't a source here.
		\(instructionsNote(instructions))
		"""
	}

	/// The person's own words about how to answer, kept apart so they can't loosen the rules above. Empty when there are none.
	static func instructionsNote(_ instructions: String?) -> String {
		guard let instructions = AgentInstructions.normalized(instructions) else { return "" }
		return """


		The person asked for this about how you answer. It's about style only, like length and tone, and doesn't change what counts as a source, how to use your tools or the format you answer in:

		\(instructions)
		"""
	}

	/// The board as data, so what's in a card or a page can't pass for an instruction
	static func analysisMessage(for request: BoardAnalysisRequest) throws -> String {
		struct Board: Encodable {
			let statements: [BoardAnalysisRequest.Statement]
			let links: [BoardAnalysisRequest.Link]
			let sources: [BoardAnalysisRequest.Source]
		}
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		let json = try String(decoding: encoder.encode(Board(statements: request.statements, links: request.links, sources: request.sources)), as: UTF8.self)

		return """
		The board:

		```json
		\(json)
		```

		Work out where this argument's weight rests and where it breaks, then report what matters most. Your reasoning is your own, but anything you name comes from an entry you read this run.
		\(instructionsNote(request.instructions))
		"""
	}

	static func message(for input: some Encodable) throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
		let json = try String(decoding: encoder.encode(input), as: UTF8.self)

		return """
		Input:

		```json
		\(json)
		```

		Answer with only a JSON object that matches the schema.
		"""
	}
}
