//
//  AskAttachment.swift
//  Ergo
//

import Foundation

/// Something that goes along with a message in a chat
nonisolated struct AskAttachment: Codable, Hashable, Identifiable {
	enum Content: Codable, Hashable {
		case library(CatalogReference)
		case text(String)

		/// `text` is what the page says, read when it's attached, since the model can't open links
		case link(URL, title: String?, text: String?)
	}

	/// Pasted text longer than this goes in as a block of its own, so it doesn't fill the composer
	static let pasteWordLimit = 50

	var id = UUID()
	var content: Content

	/// Stands in for the question when one's sent without any
	var title: String {
		switch content {
			case let .library(reference):
				reference.name
			case let .text(text):
				text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Text"
			case let .link(_, title, _):
				title ?? displayURL ?? "Web Link"
		}
	}

	var plainText: String? {
		guard case let .text(text) = content else { return nil }
		return text
	}

	/// The link without the part that's the same on every link
	var displayURL: String? {
		guard case let .link(url, _, _) = content else { return nil }
		return url.absoluteString.replacing(/^https?:\/\/(www\.)?/, with: "")
	}

	/// How the model gets it, after the question. It looks a library entry up for itself, like any other.
	var requestText: String {
		switch content {
			case let .library(reference):
				"Attached library entry: category \"\(reference.category.rawValue)\", id \"\(reference.id)\" (\(reference.name))"

			case let .text(text):
				"Attached text:\n\(text)"

			case let .link(url, title, text):
				"Attached web page: \([title, url.absoluteString].compactMap(\.self).joined(separator: "\n"))\n\n\(text ?? "Its text couldn't be read.")"
		}
	}
}
