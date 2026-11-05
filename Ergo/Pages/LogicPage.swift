//
//  LogicPage.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import ErgoTranslation
import Foundation

/// One scratchpad on the Check tab: the English, its logic, and what each letter stands for here.
/// The logic's diagnostics aren't stored, they're recomputed in milliseconds and stay current as the checker improves.
struct LogicPage: Codable, Hashable, Identifiable, Defaults.Serializable {
	/// Whichever box was edited last. The other one follows it.
	enum Source: String, Codable {
		case english, logic
	}

	var id = UUID()
	var created = Date.now
	var modified = Date.now

	var english = ""
	var logic: [LogicKeyboardEntry] = []

	/// One per letter slot, at most four words each
	var descriptors = LogicLetters.emptyDescriptors

	var source = Source.logic

	/// The last English → logic run, with its issues
	var translation: Translation?

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

	func title(letters: [String]) -> String {
		let english = english
			.split(whereSeparator: \.isNewline)
			.first
			.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
		if !english.isEmpty {
			return english
		}

		let logic = logic
			.prefix { $0 != .delimiter("\n") }
			.map { $0.glyph(letters: letters) }
			.joined()
		return logic.isEmpty ? "Untitled" : logic
	}
}
