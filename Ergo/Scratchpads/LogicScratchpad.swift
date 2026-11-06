//
//  LogicScratchpad.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import ErgoTranslation
import Foundation

/// One saved argument on the Logic tab: English over logic, and what each letter stands for.
///
/// Nothing has reached v1, so the stored properties may change until then. Sync holds `english`, `logic`,
/// `source` and `translation` together as the record's `content` (`ScratchpadRecord`).
struct LogicScratchpad: Codable, Hashable, Identifiable, Defaults.Serializable {
	/// Whichever side was edited last. The other one follows it.
	enum Source: String, Codable {
		case english, logic
	}

	var id = UUID()
	var created = Date.now
	var modified = Date.now

	/// One per letter slot, at most four words each
	var descriptors = LogicLetters.emptyDescriptors

	var english = ""
	var logic: [LogicKeyboardEntry] = []
	var source = Source.logic

	/// The last English → logic run, with its issues.
	/// The logic's diagnostics aren't stored, they're recomputed in milliseconds and stay current as the checker improves.
	var translation: Translation?

	/// Nothing written yet, so the scratchpad stays out of the list
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

	/// The first line of English, else the first line of logic, else "Untitled"
	func title(letters: [String]) -> String {
		englishLine ?? logicLine(letters: letters) ?? "Untitled"
	}

	/// Names the slots that are still free and leaves the rest as they are, so a translation
	/// never renames a letter the scratchpad already relies on
	mutating func merge(descriptors new: [String]) {
		for slot in descriptors.indices where descriptors[slot].isEmpty && new.indices.contains(slot) {
			descriptors[slot] = LogicLetters.sanitizedDescriptor(new[slot])
		}
	}
}
