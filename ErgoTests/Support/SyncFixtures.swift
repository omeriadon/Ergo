//
//  SyncFixtures.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

@testable import Ergo
import ErgoProtocol
import ErgoSync
import Foundation

extension SyncReplica {
	/// A replica that has caught up with the server, so what's recorded counts as an edit
	static func caughtUp(device: String = "test") -> SyncReplica {
		SyncReplica(clock: SyncClock(device: device), seeds: nil)
	}

	/// What another device's replica holds once it has recorded these boards, with their cards, arrows and sources
	static func holding(_ boards: Board...) throws -> SyncReplica {
		var replica = SyncReplica.caughtUp(device: "other")
		for board in boards {
			try replica.recordLocal(kind: .board, id: BoardRecord.id(board.id), fields: BoardRecord.fields(of: board))
			for statement in board.statements {
				try replica.recordLocal(kind: .statement, id: StatementRecord.id(statement.id), fields: StatementRecord.fields(of: statement, in: board.id))
			}
			for link in board.links {
				replica.recordLocal(kind: .link, id: LinkRecord.id(link.id), fields: LinkRecord.fields(of: link, in: board.id))
			}
			for source in board.sources {
				try replica.recordLocal(kind: .source, id: SourceRecord.id(source.id), fields: SourceRecord.fields(of: source, in: board.id))
			}
		}
		return replica
	}

	/// The same replica without some of its records, as if they hadn't arrived yet
	func without(_ keys: SyncRecord.Key...) -> SyncReplica {
		var kept = records
		for key in keys {
			kept[key] = nil
		}
		return SyncReplica(records: kept, clock: clock, seeds: nil)
	}

	/// The same replica with a record the server wrote
	func with(_ record: SyncRecord) -> SyncReplica {
		var kept = records
		kept[record.key] = record
		return SyncReplica(records: kept, pending: pending, cursor: cursor, clock: clock, seeds: nil)
	}
}

extension SyncRecord {
	/// The `share` record the server writes when a board is shared with this person
	static func share(of board: Board, as role: BoardRole) -> SyncRecord {
		let share = BoardShare.invited(to: board, as: role)
		let stamp = SyncStamp(time: 1_793_836_800_000, counter: 0, device: "server")
		return SyncRecord(kind: .share, id: board.id.uuidString, fields: share.fields.mapValues { SyncField(value: $0, stamp: stamp) })
	}
}

extension SyncController {
	/// A controller that has never run, so it can't reach a server, signed in or not. Its replica has caught up, so what
	/// it records can be read back from `replica`.
	static func test(boards: BoardStore, scratchpads: ScratchpadStore = .test(), signedIn: Bool = true) -> SyncController {
		let account = TranslationAccount(
			signedIn: signedIn ? SignedInAccount(server: ServerEnvironment.productionURL, id: UUID()) : nil
		)
		let sync = SyncController(account: account, boardStore: boards, scratchpadStore: scratchpads, catalog: CatalogStore())
		sync.replica = .caughtUp()
		TestDefaults.onFinish { sync.stop() }
		return sync
	}

	/// Whether the replica holds this record and it isn't a tombstone
	func isAlive(_ kind: SyncKind, _ id: UUID) -> Bool {
		replica[kind, id.uuidString].map { !$0.isDeleted } ?? false
	}

	/// Whether the replica holds a tombstone for this record
	func isDeleted(_ kind: SyncKind, _ id: UUID) -> Bool {
		replica[kind, id.uuidString]?.isDeleted ?? false
	}
}
