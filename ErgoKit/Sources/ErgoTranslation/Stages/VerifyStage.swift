//
//  VerifyStage.swift
//  ErgoKit
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation

/// Compares the original English with the logic read back as English
public enum VerifyStage: TranslationStage {
	public static let name = "verify"

	public struct Input: Codable, Sendable {
		public let english: String

		/// `LogicEnglish.text`, which is exact
		public let reading: String

		public init(english: String, reading: String) {
			self.english = english
			self.reading = reading
		}
	}

	public struct Output: Codable, Sendable {
		public let matches: Bool
		public let differences: [String]

		public init(matches: Bool, differences: [String]) {
			self.matches = matches
			self.differences = differences
		}
	}

	public static let outputSchema = JSONSchema.object([
		.init("matches", .boolean(description: "Whether the reading claims exactly what the original does, nothing more and nothing less")),
		.init("differences", .array(.string(), description: "Each difference in meaning, short, in the style of a compiler error")),
	])
}
