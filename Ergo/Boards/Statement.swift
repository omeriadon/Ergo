//
//  Statement.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import Foundation

// `Statement`, `Link` and everything inside them are saved in users' Defaults as synthesized Codable,
// and `Statement` is also what sync records are made from. Nothing has reached v1, so they may change until then.

/// One claim on the canvas: its English, and where the box sits.
nonisolated struct Statement: Codable, Hashable, Identifiable, Sendable, ArgumentNode {
	var id: UUID

	/// The centre of the box, in canvas coordinates
	var position: CanvasPoint

	var english: String

	/// The source this card was broken down from, which puts it in that source's region
	var source: BoardSource.ID?

	/// What goes in the card, shown while its English is empty. A template's cards have one (`BoardTemplate`).
	var placeholder: String?

	init(
		id: UUID = UUID(),
		position: CanvasPoint = .zero,
		english: String = ""
	) {
		self.id = id
		self.position = position
		self.english = english
	}

	var isEmpty: Bool {
		english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	/// What's shown while there's no English
	var placeholderText: String {
		placeholder ?? "Empty statement"
	}

	/// The first line of the English, nil when there is none
	var englishLine: String? {
		let line = english
			.split(whereSeparator: \.isNewline)
			.first
			.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
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
