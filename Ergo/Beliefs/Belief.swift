//
//  Belief.swift
//  Ergo
//
//  Created by Adon Omeri on 16/11/2026.
//

import CryptoKit
import Defaults
import ErgoCatalog
import Foundation

// `Belief` and `BeliefLedger` are saved in users' Defaults as synthesized Codable. Nothing has reached v1, so they may
// change until then.

/// Something the person believes, how sure they are, and every time that changed. Written by them, or an answer to one
/// of the bank's questions (`BeliefQuestionBank`).
nonisolated struct Belief: Codable, Hashable, Identifiable, Sendable {
	var id = UUID()
	var created: Date

	/// One claim. For a question, the question's own words when it was last answered.
	var statement: String

	/// 0 to 100 in steps of 10 (`BeliefScale`). Nil is "No view".
	var confidence: Int?

	/// Every rating, oldest first, the first one included
	var changes: [Change] = []

	/// The bank question it answers, nil when the person wrote it
	var question: String?

	var isArchived = false

	struct Change: Codable, Hashable, Identifiable, Sendable {
		var id = UUID()
		var date: Date

		/// Nil when there was no rating before, or it was "No view"
		var from: Int?
		var to: Int?

		/// Why, in their words
		var note: String?

		var hasMoved: Bool {
			from != to
		}
	}

	/// The question's current words, which a fix to the bank can change, else what was saved
	var displayStatement: String {
		question.flatMap(BeliefQuestionBank.question)?.statement ?? statement
	}

	/// When it was last rated
	var lastRated: Date {
		changes.last?.date ?? created
	}

	/// The rating before the last one, for showing which way it moved
	var previousConfidence: Int? {
		changes.last?.from
	}

	/// The same on every device, so a question answered on two before either syncs is one belief, not two
	static func id(answering question: String) -> UUID {
		var bytes = Array(SHA256.hash(data: Data("ergo.belief.question/\(question)".utf8)).prefix(16))
		// A name-based UUID's version and variant bits
		bytes[6] = (bytes[6] & 0x0F) | 0x50
		bytes[8] = (bytes[8] & 0x3F) | 0x80
		return UUID(uuid: (
			bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
			bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
		))
	}
}

/// Every belief on this device. Read and written through `Defaults.Keys.beliefs`, like practice progress.
nonisolated struct BeliefLedger: Codable, Hashable, Sendable, Defaults.Serializable {
	var beliefs: [Belief] = []

	func belief(_ id: Belief.ID) -> Belief? {
		beliefs.first { $0.id == id }
	}

	func belief(answering question: String) -> Belief? {
		beliefs.first { $0.question == question }
	}

	/// Not archived, the longest unrated first, so old ones come up to be looked at again
	var listed: [Belief] {
		beliefs.filter { !$0.isArchived }.sorted { $0.lastRated < $1.lastRated }
	}

	var archived: [Belief] {
		beliefs.filter(\.isArchived).sorted { $0.lastRated > $1.lastRated }
	}

	// MARK: - Sets

	/// Questions of the set with any answer, "No view" included
	func answeredCount(of set: BeliefQuestionSet) -> Int {
		set.questions.count { belief(answering: $0.id) != nil }
	}

	/// The newest answer to any of its questions
	func lastTaken(_ set: BeliefQuestionSet) -> Date? {
		set.questions.compactMap { belief(answering: $0.id)?.lastRated }.max()
	}

	/// Where taking the set picks up: the first question never answered, or the start when every one has been
	func startIndex(of set: BeliefQuestionSet) -> Int {
		set.questions.firstIndex { belief(answering: $0.id) == nil } ?? 0
	}

	// MARK: - Changing

	/// Logs an answer to a bank question, making its belief the first time. Every answer is logged, even one that
	/// didn't move, so the history shows each time the set was taken.
	mutating func answer(_ question: BeliefQuestion, confidence: Int?, at date: Date = .now) {
		if let index = beliefs.firstIndex(where: { $0.question == question.id }) {
			beliefs[index].statement = question.statement
			beliefs[index].isArchived = false
			rate(at: index, confidence: confidence, date: date)
		} else {
			var belief = Belief(id: Belief.id(answering: question.id), created: date, statement: question.statement, question: question.id)
			belief.changes = [Belief.Change(date: date, from: nil, to: confidence)]
			belief.confidence = confidence
			beliefs.append(belief)
		}
	}

	/// One the person wrote. Nil when the statement is empty.
	@discardableResult
	mutating func add(_ statement: String, confidence: Int?, at date: Date = .now) -> Belief.ID? {
		let statement = statement.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !statement.isEmpty else { return nil }
		var belief = Belief(created: date, statement: statement)
		belief.changes = [Belief.Change(date: date, from: nil, to: confidence)]
		belief.confidence = confidence
		beliefs.append(belief)
		return belief.id
	}

	/// A new rating from its own page. Only logged when it moved.
	mutating func rate(_ id: Belief.ID, confidence: Int?, at date: Date = .now) {
		guard let index = beliefs.firstIndex(where: { $0.id == id }), beliefs[index].confidence != confidence else { return }
		rate(at: index, confidence: confidence, date: date)
	}

	private mutating func rate(at index: Int, confidence: Int?, date: Date) {
		beliefs[index].changes.append(Belief.Change(date: date, from: beliefs[index].confidence, to: confidence))
		beliefs[index].confidence = confidence
	}

	/// A rewording keeps the history, since it isn't a change of mind. A question's words come from the bank.
	mutating func reword(_ id: Belief.ID, to statement: String) {
		let statement = statement.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !statement.isEmpty, let index = beliefs.firstIndex(where: { $0.id == id }), beliefs[index].question == nil else { return }
		beliefs[index].statement = statement
	}

	mutating func setNote(_ note: String, on change: Belief.Change.ID, of id: Belief.ID) {
		guard
			let index = beliefs.firstIndex(where: { $0.id == id }),
			let changeIndex = beliefs[index].changes.firstIndex(where: { $0.id == change })
		else { return }
		let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
		beliefs[index].changes[changeIndex].note = note.isEmpty ? nil : note
	}

	mutating func setArchived(_ isArchived: Bool, _ id: Belief.ID) {
		guard let index = beliefs.firstIndex(where: { $0.id == id }) else { return }
		beliefs[index].isArchived = isArchived
	}

	mutating func delete(_ id: Belief.ID) {
		beliefs.removeAll { $0.id == id }
	}
}
