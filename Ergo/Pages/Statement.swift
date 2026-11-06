//
//  Statement.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoTranslation
import Foundation

// `Statement`, `Link` and everything inside them are saved in users' Defaults as synthesized Codable,
// and `Statement` is also what sync records are made from. Never rename a case or stored property.

/// One claim on the canvas: its English, its logic, and where the box sits.
/// The logic's diagnostics aren't stored, they're recomputed in milliseconds and stay current as the checker improves.
nonisolated struct Statement: Codable, Hashable, Identifiable, Sendable, ArgumentNode {
	/// Whichever box was edited last. The other one follows it.
	enum Source: String, Codable, Sendable {
		case english, logic
	}

	var id: UUID

	/// The centre of the box, in canvas coordinates
	var position: CanvasPoint

	var english: String
	var logic: [LogicKeyboardEntry]
	var source: Source

	/// The last English → logic run, with its issues
	var translation: Translation?

	init(
		id: UUID = UUID(),
		position: CanvasPoint = .zero,
		english: String = "",
		logic: [LogicKeyboardEntry] = []
	) {
		self.id = id
		self.position = position
		self.english = english
		self.logic = logic
		source = .logic
		translation = nil
	}

	var isEmpty: Bool {
		english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && logic.isEmpty
	}

	/// The English changed since it was last translated, so the logic no longer follows from it
	var isLogicOutdated: Bool {
		source == .english && !english.isEmpty && translation?.english != english
	}

	/// The translation's issues, while they still describe the English
	var currentIssues: [TranslationIssue] {
		guard let translation, translation.english == english else { return [] }
		return translation.issues
	}

	/// The first line of the English, nil when there is none
	var englishLine: String? {
		let line = english
			.split(whereSeparator: \.isNewline)
			.first
			.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
		return line.isEmpty ? nil : line
	}

	/// The logic up to its first new line, nil when there is none
	func logicLine(letters: [String]) -> String? {
		let line = logic
			.prefix { $0 != .delimiter("\n") }
			.map { $0.glyph(letters: letters) }
			.joined()
		return line.isEmpty ? nil : line
	}
}

// MARK: - Link

/// An arrow meaning "`premise` is a premise of `conclusion`"
nonisolated struct Link: Codable, Hashable, Identifiable, Sendable, ArgumentLink {
	var id: UUID
	var premise: UUID
	var conclusion: UUID

	init(id: UUID = UUID(), premise: UUID, conclusion: UUID) {
		self.id = id
		self.premise = premise
		self.conclusion = conclusion
	}
}
