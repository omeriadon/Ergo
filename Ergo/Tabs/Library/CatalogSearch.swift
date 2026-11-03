import Foundation
import FuzzyMatch

typealias CatalogSearchField = (text: String, weight: Double)

nonisolated enum CatalogSearch {
	static let resultLimit = 30

	@concurrent
	static func ranked<T: Sendable>(
		_ items: [T],
		query: String,
		limit: Int? = nil,
		fields: @escaping @Sendable (T) -> [CatalogSearchField]
	) async throws -> [T] {
		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return [] }
		if let limit, limit <= 0 {
			try Task.checkCancellation()
			return []
		}
		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()
		var scored: [(item: T, score: Double, index: Int)] = []
		if let limit {
			scored.reserveCapacity(min(limit, items.count))
		} else {
			scored.reserveCapacity(items.count)
		}
		for (index, item) in items.enumerated() {
			try Task.checkCancellation()
			var score: Double?
			for field in fields(item) {
				try Task.checkCancellation()
				// Matcher scores are at most 1, so this field cannot improve the result.
				if let score, score >= field.weight {
					continue
				}
				if let match = matcher.score(field.text, against: prepared, buffer: &buffer) {
					score = max(score ?? 0, match.score * field.weight)
				}
			}
			if let score {
				guard let limit else {
					scored.append((item, score, index))
					continue
				}

				let insertionIndex = scored.firstIndex { existing in
					existing.score < score || (existing.score == score && existing.index > index)
				} ?? scored.endIndex
				if scored.count < limit {
					scored.insert((item, score, index), at: insertionIndex)
				} else if insertionIndex < scored.endIndex {
					scored.insert((item, score, index), at: insertionIndex)
					scored.removeLast()
				}
			}
		}
		try Task.checkCancellation()
		if limit != nil {
			return scored.map(\.item)
		}
		return scored.sorted {
			if $0.score == $1.score {
				return $0.index < $1.index
			}
			return $0.score > $1.score
		}.map(\.item)
	}
}
