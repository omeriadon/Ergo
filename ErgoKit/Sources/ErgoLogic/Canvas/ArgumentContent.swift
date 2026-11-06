//
//  ArgumentContent.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

/// The part of a statement that text carries: English for one kind of text, logic for the other
enum ArgumentContent: Hashable {
	case english(String)
	case logic([LogicKeyboardEntry])

	init(of node: some ArgumentNode, _ kind: ArgumentTextKind) {
		switch kind {
			case .english: self = .english(node.english)
			case .logic: self = .logic(node.logic)
		}
	}

	/// What two pieces of content are compared by: English with its whitespace runs collapsed,
	/// logic without new lines at either end
	var normalized: ArgumentContent {
		switch self {
			case let .english(text):
				return .english(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
			case let .logic(entries):
				let start = entries.firstIndex { $0 != .delimiter("\n") }
				let end = entries.lastIndex { $0 != .delimiter("\n") }
				guard let start, let end else { return .logic([]) }
				return .logic(Array(entries[start ... end]))
		}
	}

	var isBlank: Bool {
		switch normalized {
			case let .english(text): text.isEmpty
			case let .logic(entries): entries.isEmpty
		}
	}

	var englishText: String {
		if case let .english(text) = self {
			return text
		}
		return ""
	}

	var logicEntries: [LogicKeyboardEntry] {
		if case let .logic(entries) = self {
			return entries
		}
		return []
	}

	func write(to node: inout some ArgumentNode) {
		switch self {
			case let .english(text): node.english = text
			case let .logic(entries): node.logic = entries
		}
	}
}
