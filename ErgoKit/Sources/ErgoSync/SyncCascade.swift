//
//  SyncCascade.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

// A page is a canvas, and its statements and links are records of their own, so deleting a page can't delete them
// in the same write. Instead they're ignored while their page is deleted or missing, and pruned with it:
// the server when the page's tombstone is pruned, the replica the same way.

public extension SyncRecord {
	/// The page a statement or link belongs to. Nil for other kinds, or before its `page` field is set.
	var owningPage: String? {
		guard kind == .statement || kind == .link, case let .string(page)? = fields[SyncFieldName.page]?.value else {
			return nil
		}
		return page
	}

	/// The statement ids a link joins, as (premise, conclusion). Nil for other kinds, or before both are set.
	var joined: (premise: String, conclusion: String)? {
		guard kind == .link,
		      case let .string(premise)? = fields[SyncFieldName.premise]?.value,
		      case let .string(conclusion)? = fields[SyncFieldName.conclusion]?.value
		else {
			return nil
		}
		return (premise, conclusion)
	}
}

public extension SyncReplica {
	/// Whether the app must ignore this record: a statement or link whose page is deleted or missing, or a link
	/// whose premise or conclusion statement is deleted or missing. False for every other kind.
	///
	/// Records arrive in the order they changed, so a page can be missing only because it hasn't arrived yet.
	/// Judge after a pull finishes (`SyncApplied.syncAgain` false), not part way through.
	///
	/// A page that comes back (newer edit than its delete) brings its statements back, since nothing was removed.
	func isIgnored(_ record: SyncRecord) -> Bool {
		func missing(_ kind: SyncKind, _ id: String) -> Bool {
			self[kind, id].map(\.isDeleted) ?? true
		}

		switch record.kind {
			case .statement:
				return record.owningPage.map { missing(.page, $0) } ?? true
			case .link:
				guard let page = record.owningPage, let ends = record.joined else { return true }
				return missing(.page, page) || missing(.statement, ends.premise) || missing(.statement, ends.conclusion)
			default:
				return false
		}
	}

	/// Every record of `records` the app must ignore, see `isIgnored`
	var ignored: [SyncRecord.Key] {
		records.values.filter(isIgnored).map(\.key).sorted()
	}
}

public extension SyncApplied {
	/// The lost sides of one field of one kind. `superseded(.statement, field: SyncFieldName.content)` is every
	/// statement that needs a conflict copy: the copy is a new statement on the same page, next to the original,
	/// holding `lost.value` as its `content`. Pages made copies the same way when they carried `content`.
	func superseded(_ kind: SyncKind, field: String) -> [SupersededField] {
		superseded.filter { $0.kind == kind && $0.field == field }
	}
}
