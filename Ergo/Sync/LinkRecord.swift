//
//  LinkRecord.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoProtocol
import Foundation

/// A `Link` as a link record's fields: the page, and the statement ids at each end of the arrow
enum LinkRecord {
	static func id(_ id: Link.ID) -> String {
		id.uuidString
	}

	/// Every field but `deleted`, which is only ever sent when deleting
	static func fields(of link: Link, in page: LogicPage.ID) -> [String: JSONValue] {
		[
			SyncFieldName.page: .string(PageRecord.id(page)),
			SyncFieldName.premise: .string(StatementRecord.id(link.premise)),
			SyncFieldName.conclusion: .string(StatementRecord.id(link.conclusion)),
		]
	}

	/// Nil until both ends are set and are ids, so a link this version can't read is never deleted from here
	static func link(from record: SyncRecord) -> Link? {
		guard
			let id = UUID(uuidString: record.id),
			let ends = record.joined,
			let premise = UUID(uuidString: ends.premise),
			let conclusion = UUID(uuidString: ends.conclusion)
		else {
			return nil
		}
		return Link(id: id, premise: premise, conclusion: conclusion)
	}
}
