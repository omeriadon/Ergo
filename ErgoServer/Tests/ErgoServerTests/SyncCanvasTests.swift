//
//  SyncCanvasTests.swift
//  ErgoServer
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoProtocol
@testable import ErgoServer
import Fluent
import Foundation
import Testing
import VaporTesting

/// The statement and link kinds on the server: conflicts per statement, the owning page, and pruning what a page leaves behind
struct SyncCanvasTests {
	static let day: Int64 = 86_400_000

	static func field(_ value: JSONValue, _ offset: Int64 = 0, device: String = "A") -> SyncField {
		SyncField(value: value, stamp: stamp(offset, device: device))
	}

	/// A page tombstone from before pruning's cutoff
	static func deletedPage(_ id: String) -> SyncChange {
		let old = -100 * day
		return pageChange(id, [
			"created": field(1, old),
			"deleted": field(true, old + 1),
		])
	}

	static func statement(_ id: String, page: String?, _ english: String = "A claim", at offset: Int64 = 0) -> SyncChange {
		var fields = ["content": field(content(english), offset), "position": field(["x": 0, "y": 0], offset)]
		if let page {
			fields["page"] = field(.string(page), offset)
		}
		return statementChange(id, fields)
	}

	func keys(_ app: Application) async throws -> Set<SyncRecord.Key> {
		try await Set(SyncRecordRow.query(on: app.db).all().map(\.key))
	}

	// MARK: - Syncing

	@Test func recordsKeepTheirPage() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		try await withTestApp(.testing(scratch)) { app in
			let device = try await app.signedInAccount()
			let page = newPageID()
			let (first, second, link) = (newPageID(), newPageID(), newPageID())
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [
				pageChange(page, ["created": Self.field(1)]),
				Self.statement(first, page: page),
				Self.statement(second, page: page),
				linkChange(link, page: page, premise: first, conclusion: second),
				SyncChange(kind: .bookmark, id: "fallacy.strawman", fields: ["present": Self.field(true)]),
			]), token: device.token)

			let rows = try await SyncRecordRow.query(on: app.db).all()
			let owners = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0.page) })
			#expect(owners[SyncRecord.Key(kind: .statement, id: first)] == page)
			#expect(owners[SyncRecord.Key(kind: .link, id: link)] == page)
			#expect(owners[SyncRecord.Key(kind: .page, id: page)] == .some(nil))
			#expect(owners[SyncRecord.Key(kind: .bookmark, id: "fallacy.strawman")] == .some(nil))

			// Moving a statement to another page follows
			let other = newPageID()
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [
				statementChange(first, ["page": Self.field(.string(other), 1000)]),
			]), token: device.token)
			let moved = try #require(try await SyncRecordRow.find(SyncRecord.Key(kind: .statement, id: first), for: device.accountID, on: app.db))
			#expect(moved.page == other)
		}
	}

	/// Typing in one statement on two devices at once is a conflict for that statement only. Moving a box on one
	/// device while typing in it on another isn't a conflict at all.
	@Test func conflictsAreOneStatementsContent() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		try await withTestApp(.testing(scratch)) { app in
			let phone = try await app.signedInAccount()
			let pad = try await app.signedInAccount()
			let page = newPageID()
			let (first, second) = (newPageID(), newPageID())
			let base = Self.statement(first, page: page, "Base")
			let baseStamp = try #require(base.fields["content"]?.stamp)
			let positionStamp = try #require(base.fields["position"]?.stamp)
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [base, Self.statement(second, page: page, "Other")]), token: phone.token)
			_ = try await app.sync(SyncRequest(cursor: nil, changes: []), token: pad.token)

			let phoneEdit = Self.field(content("From the phone"), 1000, device: "phone")
			let padEdit = Self.field(content("From the pad"), 2000, device: "pad")
			let moved = Self.field(["x": 40, "y": 80], 1500, device: "phone")
			let fromPhone = try await app.sync(SyncRequest(cursor: 2, changes: [
				statementChange(first, ["content": phoneEdit, "position": moved], bases: ["content": baseStamp, "position": positionStamp]),
			]), token: phone.token)
			#expect(fromPhone.superseded == [])

			let fromPad = try await app.sync(SyncRequest(cursor: 2, changes: [
				statementChange(first, ["content": padEdit], bases: ["content": baseStamp]),
				statementChange(second, ["content": Self.field(content("Pad's other"), 2000, device: "pad")], bases: ["content": positionStamp]),
			]), token: pad.token)

			// Only the first statement's content, and only the pad hears
			#expect(fromPad.superseded == [SupersededField(kind: .statement, id: first, field: "content", lost: phoneEdit)])
			let merged = try #require(fromPad.changes.first { $0.id == first })
			#expect(merged.fields["content"] == padEdit)
			#expect(merged.fields["position"] == moved)
		}
	}

	@Test func linksRoundTrip() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		try await withTestApp(.testing(scratch)) { app in
			let phone = try await app.signedInAccount()
			let pad = try await app.signedInAccount()
			let page = newPageID()
			let (premise, conclusion, link) = (newPageID(), newPageID(), newPageID())
			let change = linkChange(link, page: page, premise: premise, conclusion: conclusion)
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [change]), token: phone.token)

			let pulled = try await app.sync(SyncRequest(cursor: nil, changes: []), token: pad.token)
			#expect(pulled.changes == [change.record])
			#expect(pulled.changes.first?.joined?.premise == premise)
			#expect(pulled.changes.first?.owningPage == page)
		}
	}

	// MARK: - Limits

	@Test func statementsAndLinksCountTowardTheLimit() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }
		var config = ServerConfig.testing(scratch)
		config.recordsPerAccount = 3

		try await withTestApp(config) { app in
			let device = try await app.signedInAccount()
			let page = newPageID()
			let (first, second) = (newPageID(), newPageID())
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [
				Self.statement(first, page: page),
				Self.statement(second, page: page),
				linkChange(newPageID(), page: page, premise: first, conclusion: second),
			]), token: device.token)

			let (status, error) = try await app.syncRefusal(
				SyncRequest(cursor: nil, changes: [Self.statement(newPageID(), page: page)]),
				token: device.token
			)
			#expect(status == .payloadTooLarge)
			#expect(error == ServiceError(code: .tooLarge, message: "Expected at most 3 synced records, found 4"))
			#expect(try await SyncRecordRow.query(on: app.db).count() == 3)

			// Editing one it has is still fine
			let edited = try await app.sync(SyncRequest(cursor: nil, changes: [Self.statement(first, page: page, "Edited", at: 1000)]), token: device.token)
			#expect(edited.changes.count == 3)
		}
	}

	@Test func theDefaultLimitFitsABigCanvas() throws {
		let scratch = try Scratch()
		defer { scratch.remove() }
		#expect(ServerConfig.testing(scratch).recordsPerAccount == 50000)
	}

	// MARK: - Pruning

	/// The page's tombstone goes, and its statements and links go with it even though they're recent
	@Test func deletedPagesTakeTheirStatementsAndLinks() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		try await withTestApp(.testing(scratch)) { app in
			let device = try await app.signedInAccount()
			let (gone, kept) = (newPageID(), newPageID())
			let (goneStatement, goneOther, goneLink) = (newPageID(), newPageID(), newPageID())
			let (keptStatement, keptLink) = (newPageID(), newPageID())
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [
				Self.deletedPage(gone),
				Self.statement(goneStatement, page: gone),
				Self.statement(goneOther, page: gone),
				linkChange(goneLink, page: gone, premise: goneStatement, conclusion: goneOther),
				pageChange(kept, ["created": Self.field(1)]),
				Self.statement(keptStatement, page: kept),
				linkChange(keptLink, page: kept, premise: keptStatement, conclusion: keptStatement),
			]), token: device.token)

			#expect(try await app.ergo.sync.prune(on: app.db) == 4)
			#expect(try await app.ergo.sync.prune(on: app.db) == 0)
			#expect(try await keys(app) == [
				SyncRecord.Key(kind: .page, id: kept),
				SyncRecord.Key(kind: .statement, id: keptStatement),
				SyncRecord.Key(kind: .link, id: keptLink),
			])

			// Only the page's tombstone made a device start over, not the records it left
			let account = try #require(try await Account.find(device.accountID, on: app.db))
			#expect(account.prunedThrough == 1)
			#expect(account.seq == 7)
			let pulled = try await app.sync(SyncRequest(cursor: 1, changes: []), token: device.token)
			#expect(Set(pulled.changes.map(\.id)) == [kept, keptStatement, keptLink])
		}
	}

	/// A page deleted a day ago isn't pruned yet, so nothing it holds is
	@Test func recentlyDeletedPagesKeepEverything() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		try await withTestApp(.testing(scratch)) { app in
			let device = try await app.signedInAccount()
			let page = newPageID()
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [
				pageChange(page, ["created": Self.field(1, -2 * Self.day), "deleted": Self.field(true, -Self.day)]),
				Self.statement(newPageID(), page: page),
			]), token: device.token)

			#expect(try await app.ergo.sync.prune(on: app.db) == 0)
			#expect(try await SyncRecordRow.query(on: app.db).count() == 2)
		}
	}

	/// Statements with no page record are kept for the same ninety days, since a page can arrive after its statements
	@Test func orphansWithNoPageAreKeptThenPruned() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		try await withTestApp(.testing(scratch)) { app in
			let device = try await app.signedInAccount()
			let alive = newPageID()
			let missing = newPageID()
			let (old, recent, noPage, living, link) = (newPageID(), newPageID(), newPageID(), newPageID(), newPageID())
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [
				pageChange(alive, ["created": Self.field(1)]),
				Self.statement(old, page: missing),
				Self.statement(recent, page: missing),
				Self.statement(noPage, page: nil),
				Self.statement(living, page: alive),
				linkChange(link, page: missing, premise: old, conclusion: recent),
			]), token: device.token)

			// Nothing's old enough yet
			#expect(try await app.ergo.sync.prune(on: app.db) == 0)

			for id in [old, noPage, link] {
				let kind: SyncKind = id == link ? .link : .statement
				let row = try #require(try await SyncRecordRow.find(SyncRecord.Key(kind: kind, id: id), for: device.accountID, on: app.db))
				row.updated = .now - TimeInterval(100 * 24 * 60 * 60)
				try await row.save(on: app.db)
			}

			#expect(try await app.ergo.sync.prune(on: app.db) == 3)
			#expect(try await keys(app) == [
				SyncRecord.Key(kind: .page, id: alive),
				SyncRecord.Key(kind: .statement, id: recent),
				SyncRecord.Key(kind: .statement, id: living),
			])
			#expect(try await Account.find(device.accountID, on: app.db)?.prunedThrough == 0)
		}
	}

	/// A deleted statement is a tombstone like any other
	@Test func deletedStatementsArePrunedLikePages() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		try await withTestApp(.testing(scratch)) { app in
			let device = try await app.signedInAccount()
			let page = newPageID()
			let (deleted, alive) = (newPageID(), newPageID())
			let old = -100 * Self.day
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [
				pageChange(page, ["created": Self.field(1, old)]),
				statementChange(deleted, [
					"page": Self.field(.string(page), old),
					"deleted": Self.field(true, old + 1),
				]),
				Self.statement(alive, page: page, at: old),
			]), token: device.token)

			#expect(try await app.ergo.sync.prune(on: app.db) == 1)
			#expect(try await keys(app) == [SyncRecord.Key(kind: .page, id: page), SyncRecord.Key(kind: .statement, id: alive)])
			#expect(try await Account.find(device.accountID, on: app.db)?.prunedThrough == 2)
		}
	}

	/// Pruning one account never touches another's
	@Test func pruningStaysWithinAnAccount() async throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		try await withTestApp(.testing(scratch)) { app in
			let mine = try await app.signedInAccount()
			let theirs = try await app.signedInAccount("someone-else")
			let page = newPageID()
			let statement = newPageID()
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [Self.deletedPage(page), Self.statement(statement, page: page)]), token: mine.token)
			// The same page id on someone else's account is a different, living page
			_ = try await app.sync(SyncRequest(cursor: nil, changes: [
				pageChange(page, ["created": Self.field(1)]),
				Self.statement(statement, page: page),
			]), token: theirs.token)

			#expect(try await app.ergo.sync.prune(on: app.db) == 2)
			let remaining = try await SyncRecordRow.query(on: app.db).all()
			#expect(remaining.count == 2)
			#expect(remaining.allSatisfy { $0.$account.id == theirs.accountID })
		}
	}
}
