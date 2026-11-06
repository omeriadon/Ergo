//
//  SyncKind.swift
//  ErgoKit
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation

/// What a record is. A string rather than an enum, so an older app can still decode a kind added later and ignore it.
public struct SyncKind: RawRepresentable, Codable, Sendable, Hashable, Comparable, ExpressibleByStringLiteral {
	public let rawValue: String

	public init(rawValue: String) {
		self.rawValue = rawValue
	}

	public init(stringLiteral value: String) {
		rawValue = value
	}

	public init(from decoder: Decoder) throws {
		rawValue = try decoder.singleValueContainer().decode(String.self)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}

	public static func < (a: SyncKind, b: SyncKind) -> Bool {
		a.rawValue < b.rawValue
	}

	/// id: the board's `UUID.uuidString`, uppercase
	public static let board: SyncKind = "board"

	/// id: `CatalogReference.id`
	public static let bookmark: SyncKind = "bookmark"

	/// id: a `SyncedSetting` raw value
	public static let setting: SyncKind = "setting"

	/// id: the statement's `UUID.uuidString`, uppercase. One claim on a board's canvas.
	public static let statement: SyncKind = "statement"

	/// id: the link's `UUID.uuidString`, uppercase. An arrow from a premise statement to a conclusion statement.
	public static let link: SyncKind = "link"

	/// id: the scratchpad's `UUID.uuidString`, uppercase. A saved argument on the Logic tab, with no children.
	public static let scratchpad: SyncKind = "scratchpad"

	public static let known: [SyncKind] = [.board, .bookmark, .setting, .statement, .link, .scratchpad]
}

// MARK: - Checks

public extension SyncKind {
	/// The field names a record of this kind may have. Empty for a kind this version doesn't know.
	var fieldNames: Set<String> {
		switch self {
			case .board:
				[SyncFieldName.created, SyncFieldName.deleted]
			case .scratchpad:
				Set([SyncFieldName.created, SyncFieldName.content, SyncFieldName.deleted]
					+ (0 ..< SyncFieldName.descriptorSlots).map(SyncFieldName.descriptor))
			case .statement:
				[SyncFieldName.board, SyncFieldName.position, SyncFieldName.content, SyncFieldName.deleted]
			case .link:
				[SyncFieldName.board, SyncFieldName.premise, SyncFieldName.conclusion, SyncFieldName.deleted]
			case .bookmark:
				[SyncFieldName.present]
			case .setting:
				[SyncFieldName.value]
			default:
				[]
		}
	}

	/// Whether `id` can name a record of this kind
	func isValid(id: String) -> Bool {
		switch self {
			case .board, .statement, .link, .scratchpad:
				UUID(uuidString: id)?.uuidString == id
			case .bookmark:
				!id.isEmpty && id.utf8.count <= 256
			case .setting:
				SyncedSetting(rawValue: id) != nil
			default:
				false
		}
	}
}
