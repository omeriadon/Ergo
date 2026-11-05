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
	/// page: a tombstone. A record is deleted while this is `true` and newer than every other field.
	public static let deleted = "deleted"

	/// page: when it was made
	public static let created = "created"

	/// page: `{ english, logic, source, translation }` together, since English and logic follow each other
	public static let content = "content"

	/// bookmark: whether it's bookmarked
	public static let present = "present"

	/// setting: the setting's value
	public static let value = "value"

	/// page: one per letter slot, so naming different letters on two devices keeps both
	public static func descriptor(_ slot: Int) -> String {
		"descriptor.\(slot)"
	}

	/// How many letter slots a page has, `LogicLetters.defaults.count`
	public static let descriptorSlots = 6
}
