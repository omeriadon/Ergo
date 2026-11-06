//
//  SyncReplica.swift
//  ErgoKit
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation

/// The device's side of sync. A plain value the app saves; it knows nothing about boards.
///
/// The app hands `recordLocal` the current fields of a record after every change, sends `makeRequest()`,
/// and gives the reply to `apply`, which says which records to write back and which values lost.
///
/// Invariants:
/// - Every field in `pending` is in `records` with the same stamp. A remote value that beats an unsent edit
///   replaces it in both, and `apply` reports the edit as superseded, so typing is never dropped silently.
/// - A field leaves `pending` only once a request carrying that exact stamp has been answered.
/// - Every stamp the clock makes is newer than every stamp in `records`.
/// - Tombstones leave `records` once they're older than `SyncLimit.tombstoneDays`, like on the server.
public struct SyncReplica: Sendable, Hashable {
	/// The last merged state of each record, local edits included. It's the base for the next edit.
	public private(set) var records: [SyncRecord.Key: SyncRecord]

	/// Local edits the server hasn't acknowledged yet
	public private(set) var pending: [SyncRecord.Key: SyncChange]

	/// The last response's cursor. Nil pulls everything.
	public private(set) var cursor: Int?

	public private(set) var clock: SyncClock

	/// Local values recorded before this replica first caught up, so possibly just a new install's defaults.
	/// When the full pull completes they fill in only the fields the server doesn't have. Nil once caught up.
	public private(set) var seeds: [SyncRecord.Key: SyncRecord]?

	/// After `reset`, the records the full pull hasn't returned yet. When it completes, the server doesn't have
	/// these, so they're pushed as they are.
	public private(set) var unconfirmed: Set<SyncRecord.Key>?

	public init(
		records: [SyncRecord.Key: SyncRecord] = [:],
		pending: [SyncRecord.Key: SyncChange] = [:],
		cursor: Int? = nil,
		clock: SyncClock,
		seeds: [SyncRecord.Key: SyncRecord]? = [:],
		unconfirmed: Set<SyncRecord.Key>? = nil
	) {
		self.records = records
		self.pending = pending
		self.cursor = cursor
		self.clock = clock
		self.seeds = seeds
		self.unconfirmed = unconfirmed
	}

	/// A new install. `device` is a random id made once per install and kept.
	public init(device: String) {
		self.init(clock: SyncClock(device: device))
	}

	public var device: String {
		clock.device
	}

	/// Whether a full pull has completed since this replica was made or reset
	public var isCaughtUp: Bool {
		seeds == nil && unconfirmed == nil
	}

	public subscript(kind: SyncKind, id: String) -> SyncRecord? {
		records[SyncRecord.Key(kind: kind, id: id)]
	}

	/// Records with a pending value over `SyncLimit.valueBytes`. They stay on this device, so the app can say so.
	public var oversized: Set<SyncRecord.Key> {
		Set(pending.values.filter { change in
			change.fields.values.contains { $0.value.byteCount > SyncLimit.valueBytes }
		}.map(\.key))
	}

	// MARK: - Local changes

	/// Records the current values of a record's fields. Only the fields whose value actually differs get a stamp,
	/// so handing over the whole record after every change costs a comparison, and writing back a remote change
	/// then reporting it here does nothing. Fields left out are left alone.
	///
	/// Every field changed by one call shares one stamp. Returns whether anything changed.
	@discardableResult
	public mutating func recordLocal(kind: SyncKind, id: String, fields: [String: JSONValue], at deviceNow: Date = .now) -> Bool {
		let key = SyncRecord.Key(kind: kind, id: id)
		let record = records[key]
		var edited: [String: JSONValue] = [:]
		var seeded: [String: JSONValue] = [:]
		for (name, value) in fields where record?.fields[name]?.value != value {
			if seeds != nil, record?.fields[name] == nil {
				if seeds?[key]?.fields[name]?.value != value {
					seeded[name] = value
				}
			} else {
				edited[name] = value
			}
		}
		guard !edited.isEmpty || !seeded.isEmpty else { return false }

		let stamp = clock.tick(at: deviceNow)
		if !seeded.isEmpty {
			var seed = seeds?[key] ?? SyncRecord(kind: kind, id: id)
			for (name, value) in seeded {
				seed.fields[name] = SyncField(value: value, stamp: stamp)
			}
			seeds?[key] = seed
		}
		if !edited.isEmpty {
			var record = record ?? SyncRecord(kind: kind, id: id)
			var change = pending[key] ?? SyncChange(kind: kind, id: id, fields: [:])
			for (name, value) in edited {
				// An edit not sent yet keeps the base it started from
				if change.fields[name] == nil {
					change.bases[name] = record.fields[name]?.stamp
				}
				let field = SyncField(value: value, stamp: stamp)
				record.fields[name] = field
				change.fields[name] = field
			}
			records[key] = record
			pending[key] = change
		}
		return true
	}

	// MARK: - Requests

	/// Pending changes in `pushesBefore` order, up to a body comfortably under `SyncLimit.requestBytes`.
	///
	/// Holds every change back until the clock has a server time, since its stamps could be refused. Leaves out
	/// fields over `SyncLimit.valueBytes`, which would be refused forever (see `oversized`).
	public func makeRequest(limit: Int? = nil) -> SyncRequest {
		var changes: [SyncChange] = []
		var bytes = 0
		for change in sendable() {
			let size = (try? JSONEncoder().encode(change).count) ?? 0
			if !changes.isEmpty, bytes + size > SyncLimit.requestBytes * 3 / 4 {
				break
			}
			changes.append(change)
			bytes += size
		}
		return SyncRequest(cursor: cursor, changes: changes, limit: limit)
	}

	private func sendable() -> [SyncChange] {
		guard clock.offset != nil else { return [] }
		return pending.values.sorted { Self.pushesBefore($0.key, $1.key) }.compactMap { change in
			var change = change
			change.fields = change.fields.filter { $0.value.value.byteCount <= SyncLimit.valueBytes }
			change.bases = change.bases.filter { change.fields[$0.key] != nil }
			return change.fields.isEmpty ? nil : change
		}
	}

	/// A board before its statements, which key order gives, and a statement before its links, which it doesn't.
	/// Another device can pull part way through a big push, and it deletes a link whose statement looks gone.
	private static func pushesBefore(_ a: SyncRecord.Key, _ b: SyncRecord.Key) -> Bool {
		if (a.kind == .link) != (b.kind == .link) {
			return b.kind == .link
		}
		return a < b
	}

	// MARK: - Responses

	/// Merges what the server sent, acknowledges what `sent` pushed, and corrects the clock.
	///
	/// `sent` must be the request this answers. A response to a request made before a `reset` still merges
	/// (merging is always safe) but doesn't move the cursor, so the reset's full pull still happens.
	public mutating func apply(_ response: SyncResponse, sent: SyncRequest, at deviceNow: Date = .now) -> SyncApplied {
		let isCurrent = sent.cursor == cursor
		var sentStamps: [SyncRecord.Key: [String: SyncStamp]] = [:]
		for change in sent.changes {
			sentStamps[change.key, default: [:]].merge(change.fields.mapValues(\.stamp)) { _, last in last }
		}

		var changed: [SyncRecord.Key] = []
		var superseded: [SupersededField] = []
		var lostHere: [SyncRecord.Key: Set<String>] = [:]
		for incoming in response.changes {
			if let stamp = incoming.newestStamp {
				clock.receive(stamp)
			}
			let key = incoming.key
			unconfirmed?.remove(key)

			let old = records[key]
			let merged = old.map { SyncRecord.merge($0, incoming) } ?? incoming
			if merged != old {
				records[key] = merged
				if !changed.contains(key) {
					changed.append(key)
				}
			}

			// Unsent edits a remote value beat. The server never saw them, so this is the only place they're caught.
			for (name, field) in pending[key]?.fields ?? [:] where merged.fields[name] != field && sentStamps[key]?[name] != field.stamp {
				if merged.fields[name]?.value != field.value {
					superseded.append(SupersededField(kind: key.kind, id: key.id, field: name, lost: field))
					lostHere[key, default: []].insert(name)
				}
				drop(name, of: key)
			}

			// The server's copy is missing something this replica has, after a reset or the server pruning a
			// tombstone. Pushing it back is what makes every copy agree.
			let missing = merged.fields.filter { name, field in incoming.fields[name] != field && pending[key]?.fields[name] == nil }
			if !missing.isEmpty {
				pending[key, default: SyncChange(kind: key.kind, id: key.id, fields: [:])].fields.merge(missing) { pending, _ in pending }
			}
		}

		acknowledge(sent)

		for field in response.superseded {
			clock.receive(field.lost.stamp)
			// A newer edit of ours grew from this lost one, and that edit is either still pending or reported above
			let isOurs = sentStamps[field.key]?[field.field] == field.lost.stamp
			let grewOn = pending[field.key]?.fields[field.field] != nil || lostHere[field.key]?.contains(field.field) == true
			if !(isOurs && grewOn) {
				superseded.append(field)
			}
		}

		clock.adjust(serverTime: response.serverTime, at: deviceNow)
		if isCurrent {
			cursor = response.cursor
			if !response.more, !isCaughtUp {
				finishCatchingUp()
			}
		}
		restampFuture(at: deviceNow)
		pruneTombstones(at: deviceNow)

		return SyncApplied(
			changed: changed.compactMap { records[$0] },
			superseded: superseded,
			syncAgain: response.more || !sendable().isEmpty
		)
	}

	private mutating func acknowledge(_ sent: SyncRequest) {
		for change in sent.changes {
			guard var waiting = pending[change.key] else { continue }
			for (name, field) in change.fields {
				guard let current = waiting.fields[name] else { continue }
				if current.stamp == field.stamp {
					waiting.fields[name] = nil
					waiting.bases[name] = nil
				} else {
					// Edited again during the request, from what was just sent
					waiting.bases[name] = field.stamp
				}
			}
			pending[change.key] = waiting.fields.isEmpty ? nil : waiting
		}
	}

	private mutating func drop(_ name: String, of key: SyncRecord.Key) {
		pending[key]?.fields[name] = nil
		pending[key]?.bases[name] = nil
		if pending[key]?.fields.isEmpty == true {
			pending[key] = nil
		}
	}

	/// The full pull is done, so whatever the server didn't have goes up
	private mutating func finishCatchingUp() {
		var pushes: [SyncRecord.Key: [String: SyncField]] = [:]
		// In order, since whether a statement or link is ignored depends on the seeds merged before it
		for (key, seed) in (seeds ?? [:]).sorted(by: { Self.pushesBefore($0.key, $1.key) }) where !seed.isDeleted && !isIgnored(seed) {
			let missing = seed.fields.filter { records[key]?.fields[$0.key] == nil }
			if !missing.isEmpty {
				records[key, default: SyncRecord(kind: key.kind, id: key.id)].merge(missing)
				pushes[key, default: [:]].merge(missing) { a, _ in a }
			}
		}
		for key in unconfirmed ?? [] {
			// Ignored records are what the server pruned with their board, so they stay down
			guard let record = records[key], !record.isDeleted, !isIgnored(record) else { continue }
			pushes[key, default: [:]].merge(record.fields) { a, _ in a }
		}
		seeds = nil
		unconfirmed = nil

		for (key, fields) in pushes {
			pending[key, default: SyncChange(kind: key.kind, id: key.id, fields: [:])].fields.merge(fields) { pending, _ in pending }
		}
	}

	/// Stamps made while the device clock was far ahead would be refused, so once the clock is corrected
	/// they're made again. Only unsent ones can be that far ahead, so nothing the server has moves.
	private mutating func restampFuture(at deviceNow: Date) {
		let limit = clock.now(deviceNow) + SyncLimit.futureStamp / 2
		guard let last = clock.last, last.time > limit else { return }

		func isFuture(_ key: SyncRecord.Key, _ name: String, _ field: SyncField) -> Bool {
			field.stamp.time > limit && pending[key]?.fields[name]?.stamp == field.stamp
		}

		// The clock goes back only as far as the newest stamp anyone else might have
		var kept: SyncStamp?
		for (key, record) in records {
			for (name, field) in record.fields where !isFuture(key, name, field) {
				kept = max(kept ?? field.stamp, field.stamp)
			}
		}
		clock.rewind(to: kept)
		let stamp = clock.tick(at: deviceNow)

		for (key, change) in pending {
			for (name, field) in change.fields where field.stamp > stamp {
				pending[key]?.fields[name]?.stamp = stamp
				records[key]?.fields[name]?.stamp = stamp
			}
		}
		for (key, seed) in seeds ?? [:] {
			for (name, field) in seed.fields where field.stamp > stamp {
				seeds?[key]?.fields[name]?.stamp = stamp
			}
		}
	}

	/// The server prunes tombstones after `SyncLimit.tombstoneDays`, so they're dropped here too, rather than keeping
	/// deleted boards' text on the device forever
	///
	/// A pruned board takes its statements and links with it, like on the server. Without that a reset would push
	/// them back up as orphans.
	private mutating func pruneTombstones(at deviceNow: Date) {
		let cutoff = clock.now(deviceNow) - Int64(SyncLimit.tombstoneDays) * 86_400_000
		func isOld(_ key: SyncRecord.Key, _ record: SyncRecord) -> Bool {
			guard record.isDeleted, pending[key] == nil, let deleted = record.fields[SyncFieldName.deleted] else { return false }
			return deleted.stamp.time < cutoff
		}

		let boards = Set(records.filter { key, record in key.kind == .board && isOld(key, record) }.keys.map(\.id))
		records = records.filter { key, record in
			if isOld(key, record) {
				return false
			}
			guard !boards.isEmpty, pending[key] == nil, let board = record.owningBoard else { return true }
			return !boards.contains(board)
		}
	}

	// MARK: - Starting over

	/// For signing out and `syncResetRequired`: forgets the cursor but keeps what's merged and pending, so the next
	/// sync pulls everything, merges it by stamp as usual, and pushes back what the server doesn't have.
	/// Signing in again, to any account, then loses nothing.
	public mutating func reset() {
		cursor = nil
		unconfirmed = Set(records.keys).union(unconfirmed ?? [])
	}

	/// For when the server refuses a stamp as too far ahead: the next sync measures the clock before pushing,
	/// and `apply` then restamps what was refused
	public mutating func recalibrate() {
		clock.forgetOffset()
	}
}

/// What applying a sync response changed
public struct SyncApplied: Sendable, Hashable {
	/// Every record whose merged state changed, for the app to write back. Includes tombstones (`isDeleted`),
	/// and kinds or fields this version doesn't know, which the app skips. A stamp-only change counts too,
	/// since `isDeleted` and `newestStamp` follow the stamps.
	public var changed: [SyncRecord]

	/// The losing sides of concurrent edits this device made, found by the server or by this replica.
	/// Each reaches exactly one device. The app copies a board's lost `content` into a new board and ignores the rest.
	public var superseded: [SupersededField]

	/// Sync again straight away: there's more to pull, or changes this request held back
	public var syncAgain: Bool

	public init(changed: [SyncRecord], superseded: [SupersededField], syncAgain: Bool) {
		self.changed = changed
		self.superseded = superseded
		self.syncAgain = syncAgain
	}
}

// MARK: - Coding

/// Saved as plain lists, since JSON can't key an object by a struct
extension SyncReplica: Codable {
	private enum CodingKeys: String, CodingKey {
		case records, pending, cursor, clock, seeds, unconfirmed
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let records = try container.decode([SyncRecord].self, forKey: .records)
		let pending = try container.decode([SyncChange].self, forKey: .pending)
		let seeds = try container.decodeIfPresent([SyncRecord].self, forKey: .seeds)
		try self.init(
			records: Dictionary(records.map { ($0.key, $0) }) { _, last in last },
			pending: Dictionary(pending.map { ($0.key, $0) }) { _, last in last },
			cursor: container.decodeIfPresent(Int.self, forKey: .cursor),
			clock: container.decode(SyncClock.self, forKey: .clock),
			seeds: seeds.map { seeds in Dictionary(seeds.map { ($0.key, $0) }) { _, last in last } },
			unconfirmed: container.decodeIfPresent([SyncRecord.Key].self, forKey: .unconfirmed).map(Set.init)
		)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(records.values.sorted { $0.key < $1.key }, forKey: .records)
		try container.encode(pending.values.sorted { $0.key < $1.key }, forKey: .pending)
		try container.encodeIfPresent(cursor, forKey: .cursor)
		try container.encode(clock, forKey: .clock)
		try container.encodeIfPresent(seeds?.values.sorted { $0.key < $1.key }, forKey: .seeds)
		try container.encodeIfPresent(unconfirmed?.sorted(), forKey: .unconfirmed)
	}
}
