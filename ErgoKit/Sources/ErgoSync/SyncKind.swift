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

	/// id: the page's `UUID.uuidString`, uppercase
	public static let page: SyncKind = "page"

	/// id: `CatalogReference.id`
	public static let bookmark: SyncKind = "bookmark"

	/// id: a `SyncedSetting` raw value
	public static let setting: SyncKind = "setting"

	public static let known: [SyncKind] = [.page, .bookmark, .setting]
}

// MARK: - Checks

public extension SyncKind {
	/// The field names a record of this kind may have. Empty for a kind this version doesn't know.
	var fieldNames: Set<String> {
		switch self {
			case .page:
				Set([SyncFieldName.created, SyncFieldName.content, SyncFieldName.deleted]
					+ (0 ..< SyncFieldName.descriptorSlots).map(SyncFieldName.descriptor))
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
			case .page:
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
