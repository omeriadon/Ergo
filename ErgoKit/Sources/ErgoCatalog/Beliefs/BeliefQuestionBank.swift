//
//  BeliefQuestionBank.swift
//  ErgoKit
//
//  Created by Adon Omeri on 16/11/2026.
//

import Foundation

/// One claim to rate, from `beliefQuestions.json`. Answering it makes or updates the person's belief about it.
public struct BeliefQuestion: Codable, Hashable, Sendable, Identifiable {
	/// What answers are saved under. Never changes once shipped.
	public let id: String

	/// A claim, never a question: "We have free will"
	public let statement: String

	/// Library entries for the positions or thinkers behind it, as `category/id`
	public let entries: [String]

	public init(id: String, statement: String, entries: [String] = []) {
		self.id = id
		self.statement = statement
		self.entries = entries
	}

	private enum Key: String, CodingKey {
		case id, statement, entries
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: Key.self)
		try self.init(
			id: container.decode(String.self, forKey: .id),
			statement: container.decode(String.self, forKey: .statement),
			entries: container.decodeIfPresent([String].self, forKey: .entries) ?? []
		)
	}
}

/// A themed set of questions, taken one at a time
public struct BeliefQuestionSet: Codable, Hashable, Sendable, Identifiable {
	public let id: String
	public let title: String

	/// One sentence for its row
	public let summary: String

	/// `#RRGGBB`. See `HexColor`.
	public let color: String

	public let questions: [BeliefQuestion]

	public init(id: String, title: String, summary: String, color: String, questions: [BeliefQuestion]) {
		self.id = id
		self.title = title
		self.summary = summary
		self.color = color
		self.questions = questions
	}
}

/// The hand-written sets in `beliefQuestions.json`, in order.
///
/// The file only grows at the end, and ids never change, since answers are saved under them. A set or question this
/// version can't read is skipped rather than losing the rest.
public enum BeliefQuestionBank {
	public static let sets: [BeliefQuestionSet] = {
		guard let url = LibraryCatalog.url(of: "beliefQuestions"), let data = try? Data(contentsOf: url) else {
			return []
		}
		return (try? sets(in: data)) ?? []
	}()

	public static func sets(in data: Data) throws -> [BeliefQuestionSet] {
		try JSONDecoder().decode(File.self, from: data).sets
	}

	public static func set(_ id: String) -> BeliefQuestionSet? {
		sets.first { $0.id == id }
	}

	/// The set a question is in
	public static func set(containing question: String) -> BeliefQuestionSet? {
		sets.first { $0.questions.contains { $0.id == question } }
	}

	public static func question(_ id: String) -> BeliefQuestion? {
		for set in sets {
			if let question = set.questions.first(where: { $0.id == id }) {
				return question
			}
		}
		return nil
	}

	private struct File: Decodable {
		let sets: [BeliefQuestionSet]

		private enum Key: String, CodingKey {
			case sets
		}

		init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: Key.self)
			sets = try container.decode([Readable<RawSet>].self, forKey: .sets).compactMap(\.value).map(\.set)
		}
	}

	/// A set whose unreadable questions have been dropped
	private struct RawSet: Decodable {
		let set: BeliefQuestionSet

		private enum Key: String, CodingKey {
			case id, title, summary, color, questions
		}

		init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: Key.self)
			set = try BeliefQuestionSet(
				id: container.decode(String.self, forKey: .id),
				title: container.decode(String.self, forKey: .title),
				summary: container.decodeIfPresent(String.self, forKey: .summary) ?? "",
				color: container.decode(String.self, forKey: .color),
				questions: container.decode([Readable<BeliefQuestion>].self, forKey: .questions).compactMap(\.value)
			)
		}
	}

	/// Nil instead of failing the whole file
	private struct Readable<Value: Decodable>: Decodable {
		let value: Value?

		init(from decoder: any Decoder) throws {
			value = try? Value(from: decoder)
		}
	}
}

/// How sure someone is that a claim is true, 0 to 100 in steps of 10, and the words for it
public enum BeliefScale {
	public static let range = 0 ... 100
	public static let step = 10

	/// Where a new rating starts
	public static let middle = 50

	/// Rounded to the nearest step and kept in range
	public static func snapped(_ value: Double) -> Int {
		let stepped = Int((value / Double(step)).rounded()) * step
		return min(max(stepped, range.lowerBound), range.upperBound)
	}

	public static func words(for confidence: Int) -> String {
		switch confidence {
			case ..<20:
				"Very unlikely"
			case ..<40:
				"Unlikely"
			case ...60:
				"Unsure"
			case ...80:
				"Likely"
			default:
				"Very likely"
		}
	}
}
