//
//  SyncService.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Fluent
import Foundation
import Logging
import SQLKit

/// Applies a push and answers the pull after it, in one transaction per request, with the same merge the app runs.
/// Every record that changes takes the account's next seq, so a cursor says exactly what a device has seen.
struct SyncService: Sendable {
	let vault: CredentialVault
	let live: SyncLive
	var recordsPerAccount = SyncLimit.recordsPerAccount

	/// A response's records stop here, even under `limit`, so a board of big records stays a sensible size
	static let responseBytes = 4 << 20

	// MARK: - Syncing

	/// Throws a `ServiceError`. Tells the account's other devices after a change, never the one that pushed.
	func apply(
		_ request: SyncRequest,
		account id: UUID,
		token: UUID?,
		on database: any Database,
		logger: Logger,
		now: Date = .now
	) async throws -> SyncResponse {
		try SyncLimits.check(request, now: now)
		let changes = request.changes.filter { !$0.fields.isEmpty }
		let limit = min(request.limit ?? SyncLimit.defaultRecords, SyncLimit.maxRecords)

		let (response, changed, latest) = try await database.transaction { database in
			let account = try await Self.lock(id, on: database)
			if let cursor = request.cursor, cursor < account.prunedThrough {
				throw ServiceError(code: .syncResetRequired, message: "Expected a full sync, old deletions this device hasn't seen were cleaned up")
			}
			// Only from a cursor of another account's, which a device that signed in again could still have
			if let cursor = request.cursor, cursor > account.seq {
				throw ServiceError(code: .syncResetRequired, message: "Expected a cursor up to \(account.seq), found \(cursor)")
			}

			var superseded: [SupersededField] = []
			var changed = 0
			var count: Int?
			for change in changes {
				let row = try await SyncRecordRow.find(change.key, for: id, on: database)
				let stored = try row.map { try open($0, logger: logger) }
				if row == nil {
					let existing = if let count {
						count
					} else {
						try await SyncRecordRow.query(on: database).filter(\.$account.$id == id).count()
					}
					let total = existing + 1
					guard total <= recordsPerAccount else {
						throw ServiceError(code: .tooLarge, message: "Expected at most \(recordsPerAccount) synced records, found \(total)")
					}
					count = total
				}

				var record = stored ?? SyncRecord(kind: change.kind, id: change.id)
				superseded += record.apply(change)
				guard record != stored else { continue }

				account.seq += 1
				let updated = row ?? SyncRecordRow(account: id, key: change.key)
				try updated.store(record, seq: account.seq, vault: vault, now: now)
				try await updated.save(on: database)
				changed += 1
			}
			if changed > 0 {
				try await account.save(on: database)
			}

			let (records, more) = try await board(of: account, after: request.cursor ?? 0, limit: limit, on: database, logger: logger)
			let response = SyncResponse(
				cursor: more ? records.last?.seq ?? account.seq : account.seq,
				changes: records.map(\.record),
				more: more,
				superseded: superseded,
				serverTime: now
			)
			return (response, changed, account.seq)
		}

		logger.info("Synced", metadata: [
			"pushed": "\(changes.count)",
			"changed": "\(changed)",
			"returned": "\(response.changes.count)",
			"superseded": "\(response.superseded.count)",
		])
		if changed > 0 {
			live.changed(account: id, cursor: latest, except: token)
		}
		return response
	}

	/// The rows after `cursor` in seq order, up to `limit` and `responseBytes`, and whether there are more
	private func board(
		of account: Account,
		after cursor: Int,
		limit: Int,
		on database: any Database,
		logger: Logger
	) async throws -> ([(record: SyncRecord, seq: Int)], Bool) {
		let accountID = try account.requireID()
		let rows = try await SyncRecordRow.query(on: database)
			.filter(\.$account.$id == accountID)
			.filter(\.$seq > cursor)
			.sort(\.$seq)
			.limit(limit + 1)
			.all()

		var records: [(record: SyncRecord, seq: Int)] = []
		var bytes = 0
		for row in rows.prefix(limit) {
			if !records.isEmpty, bytes + row.fields.count > Self.responseBytes {
				break
			}
			try records.append((open(row, logger: logger), row.seq))
			bytes += row.fields.count
		}
		return (records, rows.count > records.count)
	}

	/// Unsealing only fails with the wrong key or a damaged row. Logs which row, never what's in it.
	func open(_ row: SyncRecordRow, logger: Logger) throws -> SyncRecord {
		do {
			return try row.record(vault)
		} catch {
			logger.error("Couldn't unseal a synced record", metadata: ["kind": "\(row.kind)", "seq": "\(row.seq)"])
			throw ServiceError.internalFailure
		}
	}

	// MARK: - Pruning

	/// Deletes tombstones older than `SyncLimit.tombstoneDays`, and moves each account's `prunedThrough` past them,
	/// so a device that might have missed one is told to start over. Returns how many records went.
	///
	/// It also deletes what a deleted board leaves behind, since the board's own record can't take them with it:
	/// - the statements and links of every board whose tombstone is pruned, whatever their age
	/// - statements and links with no board record at all (or no `board` field) that haven't changed in as long
	///
	/// Those don't move `prunedThrough`: a device that has them ignores them, because their board is deleted or missing.
	@discardableResult
	func prune(now: Date = .now, on database: any Database) async throws -> Int {
		let cutoff = now - TimeInterval(SyncLimit.tombstoneDays) * 24 * 60 * 60
		let tombstoned = try await SyncRecordRow.query(on: database)
			.filter(\.$tombstone < cutoff)
			.field(\.$account.$id)
			.unique()
			.all()
			.map(\.$account.id)
		let withOldChildren = try await SyncRecordRow.query(on: database)
			.filter(\.$kind ~~ Self.childKinds)
			.filter(\.$updated < cutoff)
			.field(\.$account.$id)
			.unique()
			.all()
			.map(\.$account.id)

		var pruned = 0
		for id in Set(tombstoned + withOldChildren) {
			pruned += try await database.transaction { database in
				guard let account = try? await Self.lock(id, on: database) else { return 0 }
				return try await prune(account, before: cutoff, on: database)
			}
		}
		return pruned
	}

	/// Statements and links, the kinds that belong to a board
	private static let childKinds = [SyncKind.statement.rawValue, SyncKind.link.rawValue]

	private func prune(_ account: Account, before cutoff: Date, on database: any Database) async throws -> Int {
		let id = try account.requireID()
		let tombstones = try await SyncRecordRow.query(on: database)
			.filter(\.$account.$id == id)
			.filter(\.$tombstone < cutoff)
			.all()
		var doomed = Set(tombstones.compactMap(\.id))

		let prunedBoards = Set(tombstones.filter { $0.kind == SyncKind.board.rawValue }.map(\.recordID))
		let liveBoards = try await Set(SyncRecordRow.query(on: database)
			.filter(\.$account.$id == id)
			.filter(\.$kind == SyncKind.board.rawValue)
			.field(\.$recordID)
			.all()
			.map(\.recordID)).subtracting(prunedBoards)
		let children = try await SyncRecordRow.query(on: database)
			.filter(\.$account.$id == id)
			.filter(\.$kind ~~ Self.childKinds)
			.field(\.$id)
			.field(\.$board)
			.field(\.$updated)
			.all()
		for child in children {
			guard let childID = child.id else { continue }
			if let board = child.board, prunedBoards.contains(board) {
				doomed.insert(childID)
			} else if child.updated < cutoff, child.board.map(liveBoards.contains) != true {
				doomed.insert(childID)
			}
		}
		guard !doomed.isEmpty else { return 0 }

		let ids = Array(doomed)
		for start in stride(from: 0, to: ids.count, by: 500) {
			try await SyncRecordRow.query(on: database).filter(\.$id ~~ ids[start ..< min(start + 500, ids.count)]).delete()
		}
		if let highest = tombstones.map(\.seq).max() {
			account.prunedThrough = max(account.prunedThrough, highest)
			try await account.save(on: database)
		}
		return doomed.count
	}

	// MARK: - Locking

	/// Starts the transaction with a write, so the database locks the account before anything is read. Another sync
	/// of the same account then waits for this one to commit, instead of reading the same seq.
	static func lock(_ id: UUID, on database: any Database) async throws -> Account {
		if let sql = database as? any SQLDatabase {
			try await sql.raw("UPDATE accounts SET seq = seq WHERE id = \(bind: id)").run()
		}
		guard let account = try await Account.find(id, on: database) else {
			throw ServiceError.unknownAccount
		}
		return account
	}
}
