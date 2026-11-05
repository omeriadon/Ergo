//
//  StagePrompts.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Foundation

/// What each stage's model is told. The instructions live in `Resources/<stage>.md`, the input travels as JSON,
/// so the user's English only ever reaches a model as a JSON string inside data, never in an instruction.
enum StagePrompts {
	struct Missing: Error, CustomStringConvertible {
		let stage: String

		var description: String {
			"Missing instructions for the '\(stage)' stage"
		}
	}

	private static let all: [String: String] = Dictionary(uniqueKeysWithValues: StageModels.stages.compactMap { stage in
		Bundle.module.url(forResource: stage, withExtension: "md")
			.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
			.map { (stage, $0) }
	})

	/// Checked at launch, so a broken bundle never gets as far as a translation
	static var missing: [String] {
		StageModels.stages.filter { all[$0] == nil }
	}

	static func instructions(for stage: String) throws -> String {
		guard let instructions = all[stage] else {
			throw Missing(stage: stage)
		}
		return instructions
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
