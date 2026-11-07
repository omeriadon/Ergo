//
//  BoardLedger.swift
//  ErgoServer
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import Fluent
import Foundation
import Logging

/// A shared board as this transaction sees it
struct SharedBoard: Sendable {
	/// The board's id as records have it, an uppercase UUID string
	let key: String
	let share: BoardShareRow
	var members: [BoardMemberRow]

	func member(of account: UUID) -> BoardMemberRow? {
		members.first { $0.$account.id == account }
	}

	var owner: BoardMemberRow? {
		member(of: share.$owner.id)
	}

	/// Every member's account but this one
	func others(than account: UUID) -> [UUID] {
		members.map(\.$account.id).filter { $0 != account }
	}

	/// What a `share` record's `members` holds: the owner, then by when they joined
	var everyone: [BoardMember] {
		let ownerID = share.$owner.id
		return members
			.sorted { a, b in
				let aIsOwner = a.$account.id == ownerID
				let bIsOwner = b.$account.id == ownerID
				if aIsOwner != bIsOwner {
					return aIsOwner
				}
				if a.joined != b.joined {
					return a.joined < b.joined
				}
				return (a.id?.uuidString ?? "") < (b.id?.uuidString ?? "")
			}
			.compactMap { row in
				row.id.map { BoardMember(id: $0, name: row.name, role: row.boardRole) }
			}
	}

	/// Nil when there's none to show. Never logged.
	func title(_ vault: CredentialVault) -> String? {
		guard let sealed = share.sealedTitle, let id = share.id, let title = try? vault.openTitle(sealed, board: id), !title.isEmpty else {
			return nil
		}
		return title
	}
}

/// What one transaction on shared boards has done, and writes it: every account it touches is locked, every record
/// takes that account's next seq, and what to tell people comes out at the end, to be done after the commit.
///
/// A value made inside the transaction and never leaving it, except for its `Effects`.
struct BoardLedger: Sendable {
	struct Effects: Sendable {
		/// Each account whose seq moved, and where it ended up
		var cursors: [UUID: Int] = [:]
		var pushes: [PushEvent] = []
	}

	let vault: CredentialVault
	let logger: Logger
	let now: Date

	/// Every account locked so far, one object each, so their seqs only ever count up
	private(set) var accounts: [UUID: Account] = [:]
	private var changed: Set<UUID> = []
	private var pushes: [PushEvent] = []

	/// Boards read so far. Rereads are wasted work, and these are kept current as members change.
	private var shares: [String: SharedBoard] = [:]
	private var unshared: Set<String> = []

	/// Board → who pushed the edits, to tell the others once at the end
	private var edited: [String: UUID] = [:]

	init(vault: CredentialVault, logger: Logger, now: Date = .now) {
		self.vault = vault
		self.logger = logger
		self.now = now
	}

	// MARK: - Locks

	/// In sorted order, so two requests locking the same accounts can't deadlock on Postgres. An account that's gone is skipped.
	mutating func lock(_ ids: some Sequence<UUID>, on database: any Database) async throws {
		for id in Set(ids).sorted(by: { $0.uuidString < $1.uuidString }) where accounts[id] == nil {
			accounts[id] = try await Self.lockIfThere(id, on: database)
		}
	}

	/// The same order, for a transaction that only needs them held
	static func lockInOrder(_ ids: some Sequence<UUID>, on database: any Database) async throws {
		for id in Set(ids).sorted(by: { $0.uuidString < $1.uuidString }) {
			_ = try await lockIfThere(id, on: database)
		}
	}

	private static func lockIfThere(_ id: UUID, on database: any Database) async throws -> Account? {
		do {
			return try await SyncService.lock(id, on: database)
		} catch let error as ServiceError where error == .unknownAccount {
			return nil
		}
	}

	// MARK: - Boards

	/// Nil when it isn't shared. Anyone who joined since the locks were taken is locked now.
	mutating func shared(_ key: String, on database: any Database) async throws -> SharedBoard? {
		if let known = shares[key] {
			return known
		}
		if unshared.contains(key) {
			return nil
		}
		// Only ever an uppercase UUID, so a board field spelled another way can't reach a shared board
		guard let id = UUID(uuidString: key), id.uuidString == key, let share = try await BoardShareRow.find(id, on: database) else {
			unshared.insert(key)
			return nil
		}
		let members = try await BoardMemberRow.query(on: database).filter(\.$board.$id == id).all()
		try await lock(members.map(\.$account.id), on: database)
		let board = SharedBoard(key: key, share: share, members: members)
		shares[key] = board
		return board
	}

	/// A board this transaction just shared
	mutating func adopt(_ board: SharedBoard) {
		shares[board.key] = board
		unshared.remove(board.key)
	}

	mutating func add(_ member: BoardMemberRow, to key: String) {
		shares[key]?.members.append(member)
	}

	// MARK: - Writing

	/// Stores `record` in the account's row, as its next seq
	mutating func store(_ record: SyncRecord, in row: SyncRecordRow?, of id: UUID, on database: any Database) async throws {
		if accounts[id] == nil {
			try await lock([id], on: database)
		}
		guard let account = accounts[id] else { return }

		account.seq += 1
		let updated = row ?? SyncRecordRow(account: id, key: record.key)
		try updated.store(record, seq: account.seq, vault: vault, now: now)
		try await updated.save(on: database)
		changed.insert(id)
	}

	/// Unsealing only fails with the wrong key or a damaged row. Logs which kind, never what's in it.
	func open(_ row: SyncRecordRow) throws -> SyncRecord {
		do {
			return try row.record(vault)
		} catch {
			logger.error("Couldn't unseal a synced record", metadata: ["kind": "\(row.kind)", "seq": "\(row.seq)"])
			throw ServiceError.internalFailure
		}
	}

	/// A server-stamped tombstone. Nothing else about the record changes, and a record that's already one stays as it is.
	mutating func tombstone(_ key: SyncRecord.Key, of account: UUID, on database: any Database) async throws {
		let row = try await SyncRecordRow.find(key, for: account, on: database)
		var record = try row.map { try open($0) } ?? SyncRecord(kind: key.kind, id: key.id)
		guard !record.isDeleted else { return }

		record.fields[SyncFieldName.deleted] = SyncField(value: .bool(true), stamp: .server(after: record.newestStamp, now: now))
		try await store(record, in: row, of: account, on: database)
	}

	/// Brings every member's `share` record up to date, leaving alone any that already says this
	mutating func writeShares(of board: SharedBoard, on database: any Database) async throws {
		let everyone = board.everyone
		for member in board.members {
			let share = try BoardShare(board: board.key, role: member.boardRole, member: member.requireID(), members: everyone)
			let key = SyncRecord.Key(kind: .share, id: board.key)
			let row = try await SyncRecordRow.find(key, for: member.$account.id, on: database)
			var record = try row.map { try open($0) } ?? SyncRecord(kind: .share, id: board.key)
			if BoardShare(record) == share {
				continue
			}

			// One stamp, newer than any tombstone it had, which is what brings back the share of someone rejoining
			let stamp = SyncStamp.server(after: record.newestStamp, now: now)
			for (name, value) in share.fields {
				record.fields[name] = SyncField(value: value, stamp: stamp)
			}
			try await store(record, in: row, of: member.$account.id, on: database)
		}
	}

	// MARK: - Joining

	/// Copies a board's records from its owner's account to a joiner's, sealed for them. Fan-out isn't counted against the
	/// record limit, and neither is this.
	mutating func copyBoard(_ key: String, from owner: UUID, to joiner: UUID, on database: any Database) async throws {
		// Only `created`: `deleted` is per person
		let boardKey = SyncRecord.Key(kind: .board, id: key)
		let ownersBoard = try await SyncRecordRow.find(boardKey, for: owner, on: database).map { try open($0) }
		let theirs = try await SyncRecordRow.find(boardKey, for: joiner, on: database)
		let stored = try theirs.map { try open($0) }
		var record = stored ?? SyncRecord(kind: .board, id: key)
		if let created = ownersBoard?.fields[SyncFieldName.created] {
			record.merge([SyncFieldName.created: created])
		}
		// A tombstone from before, for them only. Without any field at all the device wouldn't see a board.
		if record.isDeleted || record.fields.isEmpty {
			record.fields[SyncFieldName.deleted] = SyncField(value: .bool(false), stamp: .server(after: record.newestStamp, now: now))
		}
		if record != stored {
			try await store(record, in: theirs, of: joiner, on: database)
		}

		let rows = try await SyncRecordRow.query(on: database)
			.filter(\.$account.$id == owner)
			.filter(\.$board == key)
			.sort(\.$seq)
			.all()
		for row in rows {
			let existing = try await SyncRecordRow.find(row.key, for: joiner, on: database)
			// A tombstone only matters to someone who already has the record, from when they were here before
			if row.tombstone != nil, existing == nil {
				continue
			}
			// Their own record that happens to share an id, on another board
			if let existing, existing.board != key {
				continue
			}

			let incoming = try open(row)
			let stored = try existing.map { try open($0) }
			let merged = stored.map { SyncRecord.merge($0, incoming) } ?? incoming
			if merged != stored {
				try await store(merged, in: existing, of: joiner, on: database)
			}
		}
	}

	// MARK: - Leaving

	/// Someone stops being on a board, and everyone else's `members` is rewritten. `tombstoningBoard` is for being removed:
	/// someone leaving has already written their own, and an account being deleted is about to lose its rows anyway.
	mutating func remove(
		_ member: BoardMemberRow,
		from key: String,
		tombstoningBoard: Bool,
		tombstoningShare: Bool = true,
		on database: any Database
	) async throws {
		let account = member.$account.id
		let memberID = try member.requireID()
		try await BoardMemberRow.query(on: database).filter(\.$id == memberID).delete()
		shares[key]?.members.removeAll { $0.id == memberID }

		if tombstoningBoard {
			try await tombstone(SyncRecord.Key(kind: .board, id: key), of: account, on: database)
		}
		if tombstoningShare {
			try await tombstone(SyncRecord.Key(kind: .share, id: key), of: account, on: database)
		}
		if let board = shares[key] {
			try await writeShares(of: board, on: database)
		}
	}

	/// Everyone else loses the board, the owner's own copy going too when `deletingOwnersBoard`. A board that was only
	/// just shared has no `others`, so tells nobody.
	mutating func end(
		_ board: SharedBoard,
		heading: String,
		deletingOwnersBoard: Bool,
		ownerGoing: Bool = false,
		on database: any Database
	) async throws {
		let ownerID = board.share.$owner.id
		let others = board.others(than: ownerID)
		let boardKey = SyncRecord.Key(kind: .board, id: board.key)
		let shareKey = SyncRecord.Key(kind: .share, id: board.key)
		for account in others {
			try await tombstone(boardKey, of: account, on: database)
			try await tombstone(shareKey, of: account, on: database)
		}
		if !ownerGoing {
			if deletingOwnersBoard {
				try await tombstone(boardKey, of: ownerID, on: database)
			}
			try await tombstone(shareKey, of: ownerID, on: database)
		}

		let id = try board.share.requireID()
		try await BoardInviteRow.query(on: database).filter(\.$board.$id == id).delete()
		try await BoardMemberRow.query(on: database).filter(\.$board.$id == id).delete()
		try await BoardShareRow.query(on: database).filter(\.$id == id).delete()
		shares[board.key] = nil
		unshared.insert(board.key)
		edited[board.key] = nil

		if !others.isEmpty {
			pushes.append(PushEvent(board: board.key, heading: heading, title: board.title(vault), recipients: others))
		}
	}

	/// Everything an account being deleted leaves behind on other people's boards: the boards it owns go for everyone, and it
	/// leaves the rest. Its own rows are the caller's to delete, so nothing is written to them.
	mutating func removeAccount(_ account: UUID, on database: any Database) async throws {
		let memberships = try await BoardMemberRow.query(on: database).filter(\.$account.$id == account).all()
		for membership in memberships {
			let key = membership.$board.id.uuidString
			guard let board = try await shared(key, on: database) else { continue }

			if board.share.$owner.id == account {
				try await end(board, heading: "\(membership.name) deleted", deletingOwnersBoard: false, ownerGoing: true, on: database)
			} else {
				try await remove(membership, from: key, tombstoningBoard: false, tombstoningShare: false, on: database)
			}
		}
	}

	// MARK: - Pushing to a shared board

	enum Access: Sendable {
		/// Not on a shared board, so as ever
		case plain

		/// Refused, with what this account has
		case rejected

		/// Goes into the caller's own row, then `applied` works out what it means for everyone else
		case shared(String)
	}

	/// Whether this account may make this change. Every change belongs to a board: a board record's own id, or the stored
	/// row's `board`, else the incoming one, so a new kind on a board is covered without naming it.
	mutating func access(for change: SyncChange, row: SyncRecordRow?, account: UUID, on database: any Database) async throws -> Access {
		let incoming = change.record.owningBoard

		// A record moving between boards can't be fanned out right to either side
		if change.kind != .board, let stored = row?.board, change.fields[SyncFieldName.board] != nil, incoming != stored {
			if try await shared(stored, on: database) != nil {
				return .rejected
			}
			if let incoming, try await shared(incoming, on: database) != nil {
				return .rejected
			}
			return .plain
		}

		let owning: String? = change.kind == .board ? change.id : (row?.board ?? incoming)
		guard let key = owning, let board = try await shared(key, on: database) else {
			return .plain
		}
		if board.member(of: account)?.boardRole.canEdit == true {
			return .shared(key)
		}
		// Leaving works for anyone, offline included. For someone not on the board it only touches their own row.
		if change.kind == .board, change.fields.count == 1, change.fields[SyncFieldName.deleted]?.value == .bool(true) {
			return .shared(key)
		}
		return .rejected
	}

	/// After the change went into the caller's row and actually changed it
	mutating func applied(_ record: SyncRecord, access: Access, account: UUID, on database: any Database) async throws {
		guard case let .shared(key) = access, let board = try await shared(key, on: database) else { return }
		let member = board.member(of: account)

		if record.kind == .board, record.isDeleted {
			guard let member else { return }
			if member.boardRole == .owner {
				try await end(board, heading: "\(member.name) deleted", deletingOwnersBoard: true, on: database)
			} else {
				try await remove(member, from: key, tombstoningBoard: false, on: database)
			}
			return
		}

		guard member?.boardRole.canEdit == true else { return }
		try await fanOut(record, board: board, from: account, on: database)
	}

	/// Merges into every other member's row with the same key, each taking its own account's next seq. The record limit
	/// isn't checked, so no one's limit can fail someone else's push.
	private mutating func fanOut(_ record: SyncRecord, board: SharedBoard, from account: UUID, on database: any Database) async throws {
		var outgoing = record
		if record.kind == .board {
			// `deleted` is per person
			outgoing.fields = record.fields.filter { $0.key == SyncFieldName.created }
			guard !outgoing.fields.isEmpty else { return }
		}

		for target in board.others(than: account) {
			let row = try await SyncRecordRow.find(record.key, for: target, on: database)
			// So an editor can't reach a record on a board they aren't on by reusing its id
			if let row, record.kind != .board, row.board != board.key {
				continue
			}

			let stored: SyncRecord?
			do {
				stored = try row.map { try open($0) }
			} catch {
				// Their damaged row is no reason to fail this person's push
				continue
			}
			let merged = stored.map { SyncRecord.merge($0, outgoing) } ?? outgoing
			if merged != stored {
				try await store(merged, in: row, of: target, on: database)
				edited[board.key] = account
			}
		}
	}

	// MARK: - Finishing

	/// Tells someone something, on a board that may be gone by the time it's sent
	mutating func tell(_ recipients: [UUID], about board: SharedBoard, heading: String) {
		guard !recipients.isEmpty else { return }
		pushes.append(PushEvent(board: board.key, heading: heading, title: board.title(vault), recipients: recipients))
	}

	/// Saves every account that changed. The last thing in the transaction but reading, since the seqs are final now.
	mutating func finish(on database: any Database) async throws -> Effects {
		var cursors: [UUID: Int] = [:]
		for id in changed {
			guard let account = accounts[id] else { continue }
			try await account.save(on: database)
			cursors[id] = account.seq
		}
		for (key, editor) in edited {
			guard let board = shares[key], let name = board.member(of: editor)?.name else { continue }
			var event = PushEvent(board: key, heading: "\(name) edited", title: board.title(vault), recipients: board.others(than: editor))
			event.isEdit = true
			pushes.append(event)
		}
		return Effects(cursors: cursors, pushes: pushes)
	}
}
