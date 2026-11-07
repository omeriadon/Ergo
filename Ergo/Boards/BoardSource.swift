//
//  BoardSource.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoLogic
import ErgoShare
import Foundation

/// Material on a board that isn't a claim: a block of text or a web link. It can't take arrows. Cards broken down from it
/// point back at it (`Statement.source`), and together they're a region on the canvas (`CanvasRegion`).
///
/// Saved in users' Defaults as synthesized Codable. Nothing has reached v1, so it may change until then. A new kind of
/// content is a case here and in `SourceRecord.Content`.
nonisolated struct BoardSource: Codable, Hashable, Identifiable, Sendable {
	enum Content: Codable, Hashable, Sendable {
		case text(String)
		case link(URL, title: String?)
	}

	var id = UUID()

	/// The centre of the box, in canvas coordinates
	var position: CanvasPoint

	var content: Content

	var link: URL? {
		if case let .link(url, _) = content {
			url
		} else {
			nil
		}
	}

	var title: String {
		content.title
	}
}

extension BoardSource.Content {
	/// The link's title or where it goes, or the text's first line
	var title: String {
		switch self {
			case let .link(url, title):
				title ?? url.host() ?? url.absoluteString
			case let .text(text):
				text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Empty text"
		}
	}

	init(_ shared: SharedItem.Content) {
		switch shared {
			case let .text(text):
				self = .text(text)
			case let .link(url, title):
				self = .link(url, title: title)
		}
	}

	var shared: SharedItem.Content {
		switch self {
			case let .text(text):
				.text(text)
			case let .link(url, title):
				.link(url, title: title)
		}
	}
}
