//
//  BeliefRecord.swift
//  Ergo
//
//  Created by Adon Omeri on 16/11/2026.
//

import ErgoProtocol
import Foundation

/// A `Belief` as a belief record (`created`, `content` for the claim, `question`, `archived`), and each of its changes
/// as a beliefChange record of its own (`belief`, `date`, `previous`, `confidence`, `content` for the note), so ratings
/// made on two devices before either syncs are both kept.
///
/// How sure the person is isn't synced on the belief: it's the newest change's rating, so it always agrees with the
/// history, whichever device rated last.
enum BeliefRecord {
	static func id(_ id: UUID) -> String {
		id.uuidString
	}

	// MARK: - Local → record

	/// Every field but `deleted`, which is only ever sent when deleting, or as false to bring a deleted one back
	static func fields(of belief: Belief) throws -> [String: JSONValue] {
		try [
			SyncFieldName.created: SyncCoding.value(belief.created),
			SyncFieldName.content: .string(belief.statement),
			SyncFieldName.question: belief.question.map(JSONValue.string) ?? .null,
			SyncFieldName.archived: .bool(belief.isArchived),
		]
	}

	static func fields(of change: Belief.Change, in belief: Belief.ID) -> [String: JSONValue] {
		[
			SyncFieldName.belief: .string(id(belief)),
			SyncFieldName.date: .number((change.date.timeIntervalSince1970 * 1000).rounded()),
			SyncFieldName.previous: change.from.map { .number(Double($0)) } ?? .null,
			SyncFieldName.confidence: change.to.map { .number(Double($0)) } ?? .null,
			SyncFieldName.content: change.note.map(JSONValue.string) ?? .null,
		]
	}

	// MARK: - Record → local

	/// Whether this version can show the belief, so one it can't (from a newer app, or damaged) is never deleted from here
	static func canRead(_ record: SyncRecord) -> Bool {
		guard record.kind == .belief, UUID(uuidString: record.id) != nil else { return false }
		if let created = record.fields[SyncFieldName.created], (try? SyncCoding.decode(Date.self, from: created.value)) == nil {
			return false
		}
		if let content = record.fields[SyncFieldName.content] {
			guard case .string = content.value else { return false }
		}
		if let question = record.fields[SyncFieldName.question] {
			switch question.value {
				case .string, .null: break
				default: return false
			}
		}
		if let archived = record.fields[SyncFieldName.archived] {
			guard case .bool = archived.value else { return false }
		}
		return true
	}

	/// The belief a change rates, and the change. Nil until it can all be read.
	static func change(from record: SyncRecord) -> (belief: Belief.ID, change: Belief.Change)? {
		guard
			record.kind == .beliefChange,
			let id = UUID(uuidString: record.id),
			case let .string(beliefID)? = record.fields[SyncFieldName.belief]?.value,
			let belief = UUID(uuidString: beliefID),
			case let .number(milliseconds)? = record.fields[SyncFieldName.date]?.value,
			let previous = rating(record.fields[SyncFieldName.previous]?.value),
			let confidence = rating(record.fields[SyncFieldName.confidence]?.value)
		else {
			return nil
		}

		let note: String?
		switch record.fields[SyncFieldName.content]?.value {
			case let .string(text):
				note = text
			case .null, nil:
				note = nil
			default:
				return nil
		}
		let date = Date(timeIntervalSince1970: milliseconds / 1000)
		return (belief, Belief.Change(id: id, date: date, from: previous, to: confidence, note: note))
	}

	/// A rating field: a number, or null for none. The outer nil is a value this version can't read.
	private static func rating(_ value: JSONValue?) -> Int?? {
		switch value {
			case let .number(number):
				.some(Int(number))
			case .null, nil:
				.some(nil)
			default:
				nil
		}
	}

	/// The ledger as the replica now has it, built on `local`. The replica holds the merged state including local edits,
	/// so this is the local state plus what other devices changed. A belief the replica doesn't have yet, or can't read,
	/// keeps its local value. A deleted one goes, with its changes.
	static func rebuild(from replica: SyncReplica, local: BeliefLedger) -> BeliefLedger {
		var changes: [Belief.ID: [Belief.Change]] = [:]
		var recordedChanges: Set<String> = []
		for record in replica.records.values where record.kind == .beliefChange {
			recordedChanges.insert(record.id)
			guard !record.isDeleted, let (belief, change) = change(from: record) else { continue }
			changes[belief, default: []].append(change)
		}

		var rebuilt = BeliefLedger()
		var placed: Set<Belief.ID> = []
		for var belief in local.beliefs {
			placed.insert(belief.id)
			guard let record = replica[.belief, id(belief.id)] else {
				rebuilt.beliefs.append(belief)
				continue
			}
			if record.isDeleted {
				continue
			}
			if canRead(record) {
				apply(record, to: &belief)
				let unrecorded = belief.changes.filter { !recordedChanges.contains(BeliefRecord.id($0.id)) }
				apply(changes[belief.id, default: []] + unrecorded, to: &belief)
			}
			rebuilt.beliefs.append(belief)
		}

		// From other devices, oldest first
		let arrived = replica.records.values
			.filter { $0.kind == .belief && !$0.isDeleted && canRead($0) }
			.compactMap { record -> Belief? in
				guard let beliefID = UUID(uuidString: record.id), !placed.contains(beliefID) else { return nil }
				var belief = Belief(id: beliefID, created: .distantPast, statement: "")
				apply(record, to: &belief)
				apply(changes[beliefID, default: []], to: &belief)
				return belief
			}
			.sorted { ($0.created, $0.id.uuidString) < ($1.created, $1.id.uuidString) }
		rebuilt.beliefs += arrived
		return rebuilt
	}

	private static func apply(_ record: SyncRecord, to belief: inout Belief) {
		if let created = record.fields[SyncFieldName.created], let date = try? SyncCoding.decode(Date.self, from: created.value) {
			belief.created = date
		}
		if case let .string(statement)? = record.fields[SyncFieldName.content]?.value {
			belief.statement = statement
		}
		switch record.fields[SyncFieldName.question]?.value {
			case let .string(question):
				belief.question = question
			case .null:
				belief.question = nil
			default:
				break
		}
		if case let .bool(isArchived)? = record.fields[SyncFieldName.archived]?.value {
			belief.isArchived = isArchived
		}
	}

	/// Oldest first, and the newest one's rating is how sure the person is now
	private static func apply(_ changes: [Belief.Change], to belief: inout Belief) {
		belief.changes = changes.sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
		belief.confidence = belief.changes.last?.to
	}
}
