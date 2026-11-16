//
//  BeliefRecordTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 16/11/2026.
//

@testable import Ergo
import ErgoCatalog
import ErgoProtocol
import ErgoSync
import Foundation
import Testing

/// Beliefs turned into records and built back from them
struct BeliefRecordTests {
	private let start = Date(timeIntervalSince1970: 1_800_000_000)
	private let question = BeliefQuestion(id: "mind-free-will", statement: "We have free will.")

	/// One belief the person wrote and rated twice, and one answer to a question
	private func ledger() -> BeliefLedger {
		var ledger = BeliefLedger()
		let own = ledger.add("Cats are better than dogs.", confidence: 70, at: start)!
		ledger.rate(own, confidence: 40, at: start.addingTimeInterval(60))
		ledger.setNote("Met a nice dog.", on: ledger.belief(own)!.changes[1].id, of: own)
		ledger.answer(question, confidence: nil, at: start.addingTimeInterval(120))
		return ledger
	}

	private func record(_ ledger: BeliefLedger, into replica: inout SyncReplica, at date: Date) throws {
		for belief in ledger.beliefs {
			_ = try replica.recordLocal(kind: .belief, id: BeliefRecord.id(belief.id), fields: BeliefRecord.fields(of: belief), at: date)
			for change in belief.changes {
				_ = replica.recordLocal(kind: .beliefChange, id: BeliefRecord.id(change.id), fields: BeliefRecord.fields(of: change, in: belief.id), at: date)
			}
		}
	}

	// MARK: - Round trip

	@Test func aLedgerIsBuiltBackFromItsRecords() throws {
		let original = ledger()
		var replica = SyncReplica(device: "A")
		try record(original, into: &replica, at: start)

		let rebuilt = BeliefRecord.rebuild(from: replica, local: BeliefLedger())

		#expect(rebuilt.beliefs.count == 2)
		for belief in original.beliefs {
			let copy = try #require(rebuilt.belief(belief.id))
			#expect(copy.statement == belief.statement)
			#expect(copy.question == belief.question)
			#expect(copy.confidence == belief.confidence)
			#expect(copy.isArchived == belief.isArchived)
			#expect(copy.changes.map(\.id) == belief.changes.map(\.id))
			#expect(copy.changes.map(\.from) == belief.changes.map(\.from))
			#expect(copy.changes.map(\.to) == belief.changes.map(\.to))
			#expect(copy.changes.map(\.note) == belief.changes.map(\.note))
		}
	}

	/// Building back what was just recorded must record nothing new, or a remote write would sync again for ever
	@Test func rebuildingWhatWasRecordedChangesNoRecord() throws {
		var replica = SyncReplica(device: "A")
		try record(ledger(), into: &replica, at: start)

		let rebuilt = BeliefRecord.rebuild(from: replica, local: ledger())
		let before = replica.records
		try record(rebuilt, into: &replica, at: start.addingTimeInterval(600))

		#expect(replica.records == before)
	}

	// MARK: - Two devices

	@Test func ratingsFromTwoDevicesAreBothKeptAndTheNewestCounts() throws {
		var replica = SyncReplica(device: "A")
		var original = BeliefLedger()
		let id = try #require(original.add("Free will is an illusion.", confidence: 50, at: start))
		try record(original, into: &replica, at: start)

		// Another device's rating, a minute later, and this one's, half a minute later
		let theirs = Belief.Change(date: start.addingTimeInterval(60), from: 50, to: 90)
		_ = replica.recordLocal(kind: .beliefChange, id: BeliefRecord.id(theirs.id), fields: BeliefRecord.fields(of: theirs, in: id), at: start.addingTimeInterval(60))
		let ours = Belief.Change(date: start.addingTimeInterval(30), from: 50, to: 20)
		_ = replica.recordLocal(kind: .beliefChange, id: BeliefRecord.id(ours.id), fields: BeliefRecord.fields(of: ours, in: id), at: start.addingTimeInterval(30))

		let rebuilt = BeliefRecord.rebuild(from: replica, local: original)
		let belief = try #require(rebuilt.belief(id))
		#expect(belief.changes.map(\.to) == [50, 20, 90])
		#expect(belief.confidence == 90)
	}

	@Test func aQuestionHasTheSameBeliefOnEveryDevice() {
		let first = Belief.id(answering: "mind-free-will")
		#expect(first == Belief.id(answering: "mind-free-will"))
		#expect(first != Belief.id(answering: "mind-teleporter"))
		#expect(first.uuidString.dropFirst(14).first == "5")

		var ledger = BeliefLedger()
		ledger.answer(question, confidence: 60)
		#expect(ledger.beliefs.first?.id == first)
	}

	// MARK: - Deleting

	@Test func aDeletedBeliefGoesWithItsHistory() throws {
		let original = ledger()
		var replica = SyncReplica(device: "A")
		try record(original, into: &replica, at: start)
		let gone = original.beliefs[0]
		_ = replica.recordLocal(kind: .belief, id: BeliefRecord.id(gone.id), fields: [SyncFieldName.deleted: true], at: start.addingTimeInterval(600))

		let rebuilt = BeliefRecord.rebuild(from: replica, local: original)

		#expect(rebuilt.belief(gone.id) == nil)
		#expect(rebuilt.beliefs.count == 1)
	}

	// MARK: - Newer versions

	@Test func whatThisVersionCantReadIsLeftAlone() throws {
		let original = ledger()
		var replica = SyncReplica(device: "A")
		try record(original, into: &replica, at: start)
		let own = original.beliefs[0]

		// A newer app's archived flag, and a change it dated some other way
		_ = replica.recordLocal(kind: .belief, id: BeliefRecord.id(own.id), fields: [SyncFieldName.archived: .string("soon")], at: start.addingTimeInterval(600))
		let strange = UUID()
		_ = replica.recordLocal(
			kind: .beliefChange,
			id: BeliefRecord.id(strange),
			fields: [SyncFieldName.belief: .string(BeliefRecord.id(original.beliefs[1].id)), SyncFieldName.date: .string("yesterday")],
			at: start.addingTimeInterval(600)
		)

		let rebuilt = BeliefRecord.rebuild(from: replica, local: original)

		#expect(rebuilt.belief(own.id) == own)
		#expect(rebuilt.belief(original.beliefs[1].id)?.changes.contains { $0.id == strange } == false)
	}
}
