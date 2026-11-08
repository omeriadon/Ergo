//
//  SourceRecord.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoLogic
import ErgoProtocol
import Foundation

/// A `BoardSource` as a source record's fields. `position` is its own field, so dragging one never clashes with editing it.
/// Its `content` is last writer wins, with no conflict copy.
enum SourceRecord {
	/// Never rename a property: it's on the server, and other devices decode it. A `type` this version doesn't know
	/// reads as nil, so it's never deleted from here.
	struct Content: Codable, Hashable {
		var type: String
		var text: String?
		var url: String?
		var title: String?

		init(_ content: BoardSource.Content) {
			switch content {
				case let .text(text):
					type = "text"
					self.text = text
				case let .link(url, title):
					type = "link"
					self.url = url.absoluteString
					self.title = title
			}
		}

		var content: BoardSource.Content? {
			switch type {
				case "text":
					text.map { .text($0) }
				case "link":
					url.flatMap(URL.init(string:)).map { .link($0, title: title) }
				default:
					nil
			}
		}
	}

	static func id(_ id: BoardSource.ID) -> String {
		id.uuidString
	}

	/// Every field but `deleted`, which is only ever sent when deleting
	static func fields(of source: BoardSource, in board: Board.ID) throws -> [String: JSONValue] {
		try [
			SyncFieldName.board: .string(BoardRecord.id(board)),
			SyncFieldName.position: SyncCoding.value(source.position),
			SyncFieldName.content: SyncCoding.value(Content(source.content)),
		]
	}

	static func canRead(_ record: SyncRecord) -> Bool {
		source(from: record, local: nil) != nil
	}

	/// The source a record describes, built on `local` so a field the record lacks keeps its value here.
	/// Nil if a value fails to decode, or there's no content to show: then nothing local is touched.
	static func source(from record: SyncRecord, local: BoardSource?) -> BoardSource? {
		guard let id = UUID(uuidString: record.id) else { return nil }

		var content = local?.content
		if let field = record.fields[SyncFieldName.content] {
			guard let decoded = try? SyncCoding.decode(Content.self, from: field.value).content else { return nil }
			content = decoded
		}
		guard let content else { return nil }

		var position = local?.position ?? .zero
		if let field = record.fields[SyncFieldName.position] {
			guard let decoded = try? SyncCoding.decode(CanvasPoint.self, from: field.value) else { return nil }
			position = decoded
		}
		return BoardSource(id: id, position: position, content: content)
	}
}
