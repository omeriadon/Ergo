//
//  SyncField.swift
//  ErgoKit
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation

/// One named value in a record, with the stamp of the write that set it
public struct SyncField: Codable, Sendable, Hashable {
	public var value: JSONValue
	public var stamp: SyncStamp

	public init(value: JSONValue, stamp: SyncStamp) {
		self.value = value
		self.stamp = stamp
	}

	/// The field a merge keeps: the newer stamp, or on an exact tie (which honest devices never make) the greater value
	public static func newer(_ a: SyncField, _ b: SyncField) -> SyncField {
		if a.stamp != b.stamp {
			return a.stamp > b.stamp ? a : b
		}
		return JSONValue.precedes(a.value, b.value) ? b : a
	}
}

// MARK: - Names

/// The field names records use, shared so the app and the server's checks can't drift
public enum SyncFieldName {
	/// board, statement, link: a tombstone. A record is deleted while this is `true` and newer than every other field.
	public static let deleted = "deleted"

	/// board: when it was made
	public static let created = "created"

	/// statement: `{ english, logic, source, translation }` together, since English and logic follow each other.
	/// Opaque to the server. Boards used to carry this too, so the constant stays, but a board record refuses it now.
	public static let content = "content"

	/// statement, link: the owning board's id (uppercase UUID string). Statements and links whose board is deleted
	/// or missing are ignored on read and pruned by the server.
	public static let board = "board"

	/// statement: `{ x, y }` in canvas coordinates, written when a drag ends
	public static let position = "position"

	/// link: the id of the statement that is the premise, the arrow's tail
	public static let premise = "premise"

	/// link: the id of the statement that is the conclusion, the arrow's head
	public static let conclusion = "conclusion"

	/// bookmark: whether it's bookmarked
	public static let present = "present"

	/// setting: the setting's value
	public static let value = "value"

	/// board: one per letter slot, so naming different letters on two devices keeps both
	public static func descriptor(_ slot: Int) -> String {
		"descriptor.\(slot)"
	}

	/// How many letter slots a board has, `LogicLetters.defaults.count`
	public static let descriptorSlots = 6
}
