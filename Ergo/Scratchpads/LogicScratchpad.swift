//
//  LogicScratchpad.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import Foundation

/// One saved argument on the Logic tab: logic, what each letter stands for, and the logic read back as English.
///
/// Nothing has reached v1, so the stored properties may change until then. Sync holds `english` and `logic`
/// together as the record's `content` (`ScratchpadRecord`).
nonisolated struct LogicScratchpad: Codable, Hashable, Identifiable, Defaults.Serializable {
	var id = UUID()
	var created = Date.now
	var modified = Date.now

	/// Given by its owner. Empty means it's titled from what's written.
	var name = ""

	/// One per letter slot, at most four words each
	var descriptors = LogicLetters.emptyDescriptors

	/// Always `LogicEnglish`'s reading of `logic`, kept here for the list and for other devices.
	var english = ""

	/// The logic's diagnostics aren't stored, they're recomputed in milliseconds and stay current as the checker improves.
	var logic: [LogicKeyboardEntry] = []

	/// Nothing written yet, so the scratchpad stays out of the list
	var isEmpty: Bool {
		english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && logic.isEmpty
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

	/// Its name, else the first line of English, else the first line of logic, else "Untitled"
	func title(letters: [String]) -> String {
		name.trimmedNonEmpty ?? englishLine ?? logicLine(letters: letters) ?? "Untitled"
	}
}
