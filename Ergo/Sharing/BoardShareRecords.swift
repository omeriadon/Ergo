//
//  BoardShareRecords.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import Foundation

/// Reads who's on a board out of the replica's `share` records, which only the server writes.
enum BoardShareRecords {
	/// One per board that's shared with this account right now
	static func shares(in replica: SyncReplica) -> [Board.ID: BoardShare] {
		var shares: [Board.ID: BoardShare] = [:]
		for record in replica.records.values where record.kind == .share {
			if let share = BoardShare(record), let id = UUID(uuidString: share.board) {
				shares[id] = share
			}
		}
		return shares
	}

	/// Reads the record itself rather than decoding it, so one this version can't read still counts as shared
	static func isShared(_ board: String, in replica: SyncReplica) -> Bool {
		replica[.share, board]?.isDeleted == false
	}

	/// What has to go from this device when the account changes
	struct Departure {
		/// Boards this account doesn't own, for `BoardStore` to drop
		var boards: Set<Board.ID> = []

		/// Those boards' records and their statements, links and sources, and every `share` record
		var records: Set<SyncRecord.Key> = []
	}

	/// A board this account owns stays as an ordinary local board, so only its `share` record goes. Anything else
	/// shared belongs to someone else. A `share` this version can't read counts as someone else's, since nothing
	/// says otherwise, and the next pull brings it back if it's this account's.
	static func departure(from replica: SyncReplica) -> Departure {
		var departure = Departure()
		var leaving: Set<String> = []
		for record in replica.records.values where record.kind == .share {
			departure.records.insert(record.key)
			guard !record.isDeleted, BoardShare(record)?.role != .owner else { continue }
			leaving.insert(record.id)
			if let id = UUID(uuidString: record.id) {
				departure.boards.insert(id)
			}
			departure.records.insert(SyncRecord.Key(kind: .board, id: record.id))
		}
		guard !leaving.isEmpty else { return departure }

		for record in replica.records.values {
			if let board = record.owningBoard, leaving.contains(board) {
				departure.records.insert(record.key)
			}
		}
		return departure
	}
}

// MARK: - Wording

extension BoardRole {
	var label: String {
		switch self {
			case .owner:
				"Owner"
			case .editor:
				"Can edit"
			case .viewer:
				"View only"
		}
	}
}

extension BoardShare {
	/// The line under a board's title in the list
	var summary: String {
		guard role != .owner else { return "Shared" }
		guard let owner = members.first(where: { $0.role == .owner }) else { return "Shared · \(role.label)" }
		return "Shared by \(owner.name) · \(role.label)"
	}

	/// The owner first, then by name, so everyone sees the same list
	var sortedMembers: [BoardMember] {
		members.sorted { a, b in
			if (a.role == .owner) != (b.role == .owner) {
				return a.role == .owner
			}
			return a.name.localizedStandardCompare(b.name) == .orderedAscending
		}
	}
}

/// The name other people see on a board. It's only ever what the person typed, never their email.
enum SharingName {
	static let limit = 60

	static func cleaned(_ name: String) -> String {
		name.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	static func isValid(_ name: String) -> Bool {
		(1 ... limit).contains(cleaned(name).count)
	}

	/// Nil when it's fine, or still empty, which only disables the button
	static func problem(with name: String) -> String? {
		let count = cleaned(name).count
		return count > limit ? "Expected a name of at most \(limit) characters, found \(count)" : nil
	}
}

extension Error {
	/// What a sheet shows
	var sharingMessage: String {
		(self as? ServiceError)?.message ?? localizedDescription
	}
}
