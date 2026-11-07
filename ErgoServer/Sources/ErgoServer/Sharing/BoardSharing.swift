//
//  BoardSharing.swift
//  ErgoServer
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import Fluent
import Foundation
import Logging

/// Invites, members and stopping. Each member keeps their own copy of a board's records, sealed for their account, and
/// `SyncService` copies every change to the others, so a member's device does nothing different from any other sync.
///
/// See `Plans/09-Sharing.md`. Never logs a token, a title or a name.
struct BoardSharing: Sendable {
	let vault: CredentialVault
	let live: SyncLive
	let push: PushService

	/// `ServerConfig.publicURL`, what invite links are built on
	let publicURL: String

	static let inviteLifetime: TimeInterval = 30 * 24 * 60 * 60
	static let invitesPerBoard = 20
	static let titleCharacters = 200
	static let nameCharacters = 60

	// MARK: - Locks

	/// Who a push could write to, read before its transaction so they can all be locked in order: everyone on any board it
	/// touches, the caller among them. Inside the transaction the membership is read again.
	func accounts(touchedBy changes: [SyncChange], caller: UUID, on database: any Database) async throws -> Set<UUID> {
		var boards = Set<String>()
		var others: [String] = []
		for change in changes {
			if change.kind == .board {
				boards.insert(change.id)
			} else {
				others.append(change.id)
				if let board = change.record.owningBoard {
					boards.insert(board)
				}
			}
		}
		// An edit only carries the fields that changed, so usually only the stored row says what board it's on
		for start in stride(from: 0, to: others.count, by: 500) {
			let rows = try await SyncRecordRow.query(on: database)
				.filter(\.$account.$id == caller)
				.filter(\.$recordID ~~ others[start ..< min(start + 500, others.count)])
				.field(\.$board)
				.all()
			boards.formUnion(rows.compactMap(\.board))
		}

		let accounts = try await members(of: boards.compactMap { UUID(uuidString: $0) }, on: database)
		return Set(accounts).union([caller])
	}

	/// Everyone on a board with this account, read before the transaction that deletes it, so they can be locked in order
	func accounts(sharingWith account: UUID, on database: any Database) async throws -> [UUID] {
		let boards = try await BoardMemberRow.query(on: database)
			.filter(\.$account.$id == account)
			.field(\.$board.$id)
			.all()
			.map(\.$board.id)
		return try await members(of: boards, on: database)
	}

	private func members(of boards: [UUID], on database: any Database) async throws -> [UUID] {
		var accounts: [UUID] = []
		for start in stride(from: 0, to: boards.count, by: 500) {
			let rows = try await BoardMemberRow.query(on: database)
				.filter(\.$board.$id ~~ boards[start ..< min(start + 500, boards.count)])
				.field(\.$account.$id)
				.all()
			accounts += rows.map(\.$account.id)
		}
		return accounts
	}

	/// One change to a board's people: its members and the caller locked in order, the body's writes in one transaction,
	/// and live messages and pushes only after it commits.
	private func change<Value: Sendable>(
		board: UUID,
		caller: UUID,
		token: UUID?,
		on database: any Database,
		logger: Logger,
		now: Date,
		_ body: @escaping @Sendable (inout BoardLedger, any Database) async throws -> Value
	) async throws -> Value {
		let everyone = try await members(of: [board], on: database)
		let vault = vault
		let (value, effects) = try await database.transaction { database in
			var ledger = BoardLedger(vault: vault, logger: logger, now: now)
			try await ledger.lock(everyone + [caller], on: database)
			let value = try await body(&ledger, database)
			let effects = try await ledger.finish(on: database)
			return (value, effects)
		}
		await finish(effects, caller: caller, token: token, on: database, logger: logger)
		return value
	}

	/// After a commit. The pushing token already knows what it did, and every other socket hears its own account's seq.
	func finish(_ effects: BoardLedger.Effects, caller: UUID?, token: UUID?, on database: any Database, logger: Logger) async {
		for (account, cursor) in effects.cursors {
			live.changed(account: account, cursor: cursor, except: account == caller ? token : nil)
		}
		await push.deliver(effects.pushes, on: database, logger: logger)
	}

	// MARK: - Invites

	/// The first invite shares the board. Later ones refresh its title and the owner's name, so what previews and pushes
	/// show keeps up with what the owner's device last said.
	func createInvite(
		_ body: CreateBoardInvite,
		board: String?,
		account: UUID,
		token: UUID?,
		on database: any Database,
		logger: Logger,
		now: Date = .now
	) async throws -> BoardInvite {
		let boardID = try Self.boardID(board)
		let key = boardID.uuidString
		try Self.check(role: body.role)
		guard body.title.count <= Self.titleCharacters else {
			throw ServiceError(code: .invalidRequest, message: "Expected a title of at most \(Self.titleCharacters) characters, found \(body.title.count)")
		}
		let name = try Self.checked(name: body.name)
		let sealedTitle = try vault.seal(title: body.title, board: boardID)

		let secret = Account.makeToken()
		let expires = now + Self.inviteLifetime
		guard let url = URL(string: "\(publicURL)/\(ErgoProtocol.Path.join)/\(secret)") else {
			throw ServiceError.internalFailure
		}

		try await change(board: boardID, caller: account, token: token, on: database, logger: logger, now: now) { ledger, database in
			if let shared = try await ledger.shared(key, on: database) {
				guard shared.share.$owner.id == account else {
					throw ServiceError.notBoardOwner
				}
				shared.share.sealedTitle = sealedTitle
				try await shared.share.save(on: database)
				if let owner = shared.owner, owner.name != name {
					owner.name = name
					try await owner.save(on: database)
					try await ledger.writeShares(of: shared, on: database)
				}
			} else {
				guard let row = try await SyncRecordRow.find(SyncRecord.Key(kind: .board, id: key), for: account, on: database), row.tombstone == nil else {
					throw ServiceError(code: .invalidRequest, message: "Expected a synced board, sync and try again")
				}
				let share = BoardShareRow(board: boardID, owner: account, sealedTitle: sealedTitle, now: now)
				try await share.save(on: database)
				let owner = BoardMemberRow(board: boardID, account: account, role: .owner, name: name, now: now)
				try await owner.save(on: database)
				let shared = SharedBoard(key: key, share: share, members: [owner])
				ledger.adopt(shared)
				try await ledger.writeShares(of: shared, on: database)
			}

			// Expired ones go whenever a new one is made, then the oldest, so it's never over the limit
			try await BoardInviteRow.query(on: database).filter(\.$board.$id == boardID).filter(\.$expires <= now).delete()
			let open = try await BoardInviteRow.query(on: database).filter(\.$board.$id == boardID).sort(\.$created).all()
			let doomed = open.prefix(max(0, open.count - (Self.invitesPerBoard - 1))).compactMap(\.id)
			if !doomed.isEmpty {
				try await BoardInviteRow.query(on: database).filter(\.$id ~~ doomed).delete()
			}
			let invite = BoardInviteRow(board: boardID, tokenHash: Account.hash(secret), role: body.role, now: now, expires: expires)
			try await invite.save(on: database)
		}

		logger.info("Made a board invite", metadata: ["role": "\(body.role.rawValue)"])
		return BoardInvite(url: url, role: body.role, expires: expires)
	}

	func revokeInvites(board: String?, account: UUID, token: UUID?, on database: any Database, logger: Logger, now: Date = .now) async throws {
		let boardID = try Self.boardID(board)
		let key = boardID.uuidString
		try await change(board: boardID, caller: account, token: token, on: database, logger: logger, now: now) { ledger, database in
			_ = try await Self.owned(key, by: account, ledger: &ledger, on: database)
			try await BoardInviteRow.query(on: database).filter(\.$board.$id == boardID).delete()
		}
		logger.info("Revoked board invites")
	}

	// MARK: - Previews

	/// What an invite shows before joining, to anyone holding the link. Reads only.
	func preview(_ body: BoardInviteToken, on database: any Database, now: Date = .now) async throws -> BoardInvitePreview {
		let hash = Account.hash(body.token)
		guard let invite = try await BoardInviteRow.query(on: database).filter(\.$tokenHash == hash).first(), invite.expires > now,
		      let share = try await BoardShareRow.find(invite.$board.id, on: database)
		else {
			throw ServiceError.inviteClosed
		}
		let members = try await BoardMemberRow.query(on: database).filter(\.$board.$id == invite.$board.id).all()
		let board = SharedBoard(key: invite.$board.id.uuidString, share: share, members: members)
		return BoardInvitePreview(
			board: board.key,
			title: board.title(vault) ?? PushEvent.untitled,
			ownerName: board.owner?.name ?? "",
			role: invite.boardRole,
			memberCount: members.count
		)
	}

	// MARK: - Joining

	/// Copies the board in, and tells the owner. Accepting again, or as the owner, keeps the role you have.
	func accept(_ body: AcceptBoardInvite, account: UUID, token: UUID?, on database: any Database, logger: Logger, now: Date = .now) async throws -> JoinedBoard {
		let name = try Self.checked(name: body.name)
		let hash = Account.hash(body.token)
		guard let found = try await BoardInviteRow.query(on: database).filter(\.$tokenHash == hash).first() else {
			throw ServiceError.inviteClosed
		}
		let boardID = found.$board.id
		let key = boardID.uuidString

		let joined = try await change(board: boardID, caller: account, token: token, on: database, logger: logger, now: now) { ledger, database -> JoinedBoard in
			guard let invite = try await BoardInviteRow.query(on: database).filter(\.$tokenHash == hash).first(), invite.expires > now,
			      let board = try await ledger.shared(key, on: database),
			      let owner = board.owner
			else {
				throw ServiceError.inviteClosed
			}
			if let member = board.member(of: account) {
				return JoinedBoard(board: key, role: member.boardRole)
			}
			guard board.members.count < SyncLimit.membersPerBoard else {
				throw ServiceError(code: .invalidRequest, message: "Expected a board with room for one more, found \(board.members.count) people")
			}

			let member = BoardMemberRow(board: boardID, account: account, role: invite.boardRole, name: name, now: now)
			try await member.save(on: database)
			ledger.add(member, to: key)
			try await ledger.copyBoard(key, from: owner.$account.id, to: account, on: database)
			if let updated = try await ledger.shared(key, on: database) {
				try await ledger.writeShares(of: updated, on: database)
			}
			ledger.tell([owner.$account.id], about: board, heading: "\(name) joined")
			return JoinedBoard(board: key, role: member.boardRole)
		}
		logger.info("Joined a shared board", metadata: ["role": "\(joined.role.rawValue)"])
		return joined
	}

	// MARK: - Members

	/// Takes effect on their next push, which is checked against this
	func updateMember(
		board: String?,
		member: String?,
		role: BoardRole,
		account: UUID,
		token: UUID?,
		on database: any Database,
		logger: Logger,
		now: Date = .now
	) async throws {
		let boardID = try Self.boardID(board)
		let key = boardID.uuidString
		let memberID = try Self.memberID(member)
		try Self.check(role: role)

		try await change(board: boardID, caller: account, token: token, on: database, logger: logger, now: now) { ledger, database in
			let board = try await Self.owned(key, by: account, ledger: &ledger, on: database)
			let target = try Self.other(memberID, on: board)
			guard target.boardRole != role else { return }

			target.role = role.rawValue
			try await target.save(on: database)
			try await ledger.writeShares(of: board, on: database)
			ledger.tell([target.$account.id], about: board, heading: role.canEdit ? "You can now edit" : "You can now only view")
		}
	}

	/// Their rows stay, under a tombstone on the board, so pruning stays the only thing that deletes them
	func removeMember(board: String?, member: String?, account: UUID, token: UUID?, on database: any Database, logger: Logger, now: Date = .now) async throws {
		let boardID = try Self.boardID(board)
		let key = boardID.uuidString
		let memberID = try Self.memberID(member)

		try await change(board: boardID, caller: account, token: token, on: database, logger: logger, now: now) { ledger, database in
			let board = try await Self.owned(key, by: account, ledger: &ledger, on: database)
			let target = try Self.other(memberID, on: board)
			try await ledger.remove(target, from: key, tombstoningBoard: true, on: database)
			ledger.tell([target.$account.id], about: board, heading: "You were removed")
		}
	}

	/// Everyone else loses the board, the owner keeps it as an ordinary private one
	func stopSharing(board: String?, account: UUID, token: UUID?, on database: any Database, logger: Logger, now: Date = .now) async throws {
		let boardID = try Self.boardID(board)
		let key = boardID.uuidString

		try await change(board: boardID, caller: account, token: token, on: database, logger: logger, now: now) { ledger, database in
			let board = try await Self.owned(key, by: account, ledger: &ledger, on: database)
			try await ledger.end(board, heading: "You were removed", deletingOwnersBoard: false, on: database)
		}
		logger.info("Stopped sharing a board")
	}

	// MARK: - Checks

	private static func owned(_ key: String, by account: UUID, ledger: inout BoardLedger, on database: any Database) async throws -> SharedBoard {
		guard let board = try await ledger.shared(key, on: database) else {
			throw ServiceError(code: .invalidRequest, message: "Expected a shared board, found one that isn't shared")
		}
		guard board.share.$owner.id == account else {
			throw ServiceError.notBoardOwner
		}
		return board
	}

	/// A member the owner can do something to, so never the owner
	private static func other(_ id: UUID, on board: SharedBoard) throws -> BoardMemberRow {
		guard let member = board.members.first(where: { $0.id == id }) else {
			throw ServiceError(code: .invalidRequest, message: "Expected a member of this board, found none with that id")
		}
		guard member.boardRole != .owner else {
			throw ServiceError(code: .invalidRequest, message: "Expected another member, the owner can't change or remove themselves")
		}
		return member
	}

	private static func boardID(_ text: String?) throws -> UUID {
		guard let text, let id = UUID(uuidString: text), id.uuidString == text else {
			throw ServiceError(code: .invalidRequest, message: "Expected a board id to be an uppercase UUID")
		}
		return id
	}

	private static func memberID(_ text: String?) throws -> UUID {
		guard let text, let id = UUID(uuidString: text) else {
			throw ServiceError(code: .invalidRequest, message: "Expected a member id to be a UUID")
		}
		return id
	}

	private static func check(role: BoardRole) throws {
		guard role != .owner else {
			throw ServiceError(code: .invalidRequest, message: "Expected the role 'editor' or 'viewer', found 'owner'")
		}
	}

	private static func checked(name: String) throws -> String {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard (1 ... nameCharacters).contains(trimmed.count) else {
			throw ServiceError(code: .invalidRequest, message: "Expected a name of 1 to \(nameCharacters) characters, found \(trimmed.count)")
		}
		return trimmed
	}
}

extension ServiceError {
	static let inviteClosed = ServiceError(code: .invalidRequest, message: "Expected an invite that's still open, found one that expired or was revoked")
	static let notBoardOwner = ServiceError(code: .invalidRequest, message: "Expected a board you own, found one someone else shared")
}
