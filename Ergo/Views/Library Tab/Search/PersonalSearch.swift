//
//  PersonalSearch.swift
//  Ergo
//

import Foundation
import FuzzyMatch

/// One board, scratchpad or chat, copied off its store so it can be searched away from the main actor
nonisolated struct PersonalSearchDocument: Sendable {
	let id: UUID

	/// Matched loosely, since they're short and typed from memory
	let titles: [String]

	/// Matched as written, since fuzzy matching long text finds something in almost anything
	let bodies: [String]

	var isArchived = false
}

/// A document that matched, with the text around the match when it wasn't a title
nonisolated struct PersonalSearchHit: Identifiable, Hashable, Sendable {
	let id: UUID
	let snippet: String?
	let isArchived: Bool
}

/// What a query found in the person's own things, each kind newest first among equals
nonisolated struct PersonalSearchResults: Sendable {
	var boards: [PersonalSearchHit] = []
	var scratchpads: [PersonalSearchHit] = []
	var chats: [PersonalSearchHit] = []

	var isEmpty: Bool {
		boards.isEmpty && scratchpads.isEmpty && chats.isEmpty
	}

	/// For animating the list when what's in it changes
	var ids: [String] {
		(boards + scratchpads + chats).map(\.id.uuidString)
	}
}

nonisolated enum PersonalSearch {
	/// How many of each kind are shown
	static let groupLimit = 8

	/// A match in the text scores below a good title match, and a little higher at the start of a word
	static let bodyScore = 0.5
	static let bodyWordStartScore = 0.6

	@concurrent
	static func ranked(
		_ documents: [PersonalSearchDocument],
		query: String,
		limit: Int = groupLimit
	) async throws -> [PersonalSearchHit] {
		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty, limit > 0 else { return [] }
		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()
		var scored: [(hit: PersonalSearchHit, score: Double, index: Int)] = []

		for (index, document) in documents.enumerated() {
			try Task.checkCancellation()
			var score: Double?
			for title in document.titles where !title.isEmpty {
				if let match = matcher.score(title, against: prepared, buffer: &buffer) {
					score = max(score ?? 0, match.score)
				}
			}

			var snippet: String?
			// A body can't beat a title that already scores this well
			if (score ?? 0) < bodyWordStartScore {
				for body in document.bodies {
					guard let range = SearchSnippet.match(of: query, in: body) else { continue }
					let found = SearchSnippet.isWordStart(range.lowerBound, in: body) ? bodyWordStartScore : bodyScore
					if found > (score ?? 0) {
						score = found
						snippet = SearchSnippet.snippet(in: body, around: range)
					}
					break
				}
			}

			if let score {
				scored.append((PersonalSearchHit(id: document.id, snippet: snippet, isArchived: document.isArchived), score, index))
			}
		}

		try Task.checkCancellation()
		return scored
			.sorted { $0.score == $1.score ? $0.index < $1.index : $0.score > $1.score }
			.prefix(limit)
			.map(\.hit)
	}
}

/// Finding a query in a long text, and the few words around it to show
nonisolated enum SearchSnippet {
	/// Where the query first appears, ignoring case and accents
	static func match(of query: String, in text: String) -> Range<String.Index>? {
		guard !query.isEmpty, !text.isEmpty else { return nil }
		return text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
	}

	static func isWordStart(_ index: String.Index, in text: String) -> Bool {
		guard index > text.startIndex else { return true }
		let before = text[text.index(before: index)]
		return !(before.isLetter || before.isNumber)
	}

	/// The match with up to `radius` characters either side, cut at whole words, on one line
	static func snippet(in text: String, around range: Range<String.Index>, radius: Int = 40) -> String {
		var start = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
		var end = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex

		// Drop the part-word the cut landed in
		if start > text.startIndex, let space = text[start ..< range.lowerBound].firstIndex(where: \.isWhitespace) {
			start = text.index(after: space)
		}
		if end < text.endIndex, let space = text[range.upperBound ..< end].lastIndex(where: \.isWhitespace) {
			end = space
		}

		let words = text[start ..< end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
		let leading = start > text.startIndex ? "…" : ""
		let trailing = end < text.endIndex ? "…" : ""
		return leading + words + trailing
	}
}
