//
//  WebPageText.swift
//  ErgoKit
//
//  Created by Adon Omeri on 7/11/2026.
//

import Foundation

/// The readable text of a web page, as paragraphs. It's a simple scan of the HTML, not a browser: nothing runs, so a page
/// that builds itself with JavaScript has little to find.
public struct WebPageText: Hashable, Sendable {
	public let title: String?

	/// Paragraphs separated by blank lines. Empty when the page has nothing to read.
	public let text: String

	/// Shorter than this, an `<article>` or `<main>` is a teaser and the whole page is the better bet
	private static let enoughCharacters = 200

	public init(html: String) {
		var scanner = Scanner(html: html)
		scanner.run()
		title = scanner.title

		let regions = scanner.articles.closed.isEmpty ? scanner.mains.closed : scanner.articles.closed
		let longest = regions
			.map { scanner.blocks[$0] }
			.max { $0.joinedCount < $1.joinedCount }
		let blocks = if let longest, longest.joinedCount >= Self.enoughCharacters {
			Array(longest)
		} else {
			scanner.blocks
		}
		text = blocks.filter(Self.isReadable).joined(separator: "\n\n")
	}

	/// Drops what's left of menus, bylines and buttons: a few words that don't end like a sentence
	private static func isReadable(_ block: String) -> Bool {
		if let last = block.last, ".!?:\"”".contains(last) {
			return true
		}
		return block.split(whereSeparator: \.isWhitespace).count >= 4
	}
}

private extension ArraySlice<String> {
	var joinedCount: Int {
		reduce(0) { $0 + $1.count }
	}
}

// MARK: - Scanner

/// Which blocks fall inside each outermost `<article>`, or each outermost `<main>`
private struct Region {
	private var open: (start: Int, depth: Int)?
	private(set) var closed: [Range<Int>] = []

	mutating func tag(isClosing: Bool, at block: Int) {
		if !isClosing {
			open = open.map { ($0.start, $0.depth + 1) } ?? (block, 1)
		} else if let current = open {
			if current.depth == 1 {
				finish(at: block)
			} else {
				open = (current.start, current.depth - 1)
			}
		}
	}

	mutating func finish(at block: Int) {
		if let current = open {
			closed.append(current.start ..< block)
			open = nil
		}
	}
}

private struct Scanner {
	/// What's inside these is never text, and they can't nest, so they're jumped over to their closing tag
	private static let rawElements: Set<String> = ["script", "style", "noscript", "template", "textarea", "iframe", "svg", "canvas"]

	/// Page furniture, which can nest
	private static let skippedElements: Set<String> = ["nav", "header", "footer", "aside", "button", "select", "menu", "dialog"]

	/// What starts a new paragraph
	private static let blockElements: Set<String> = [
		"address", "article", "blockquote", "body", "br", "dd", "details", "div", "dl", "dt", "figcaption", "figure",
		"h1", "h2", "h3", "h4", "h5", "h6", "hr", "li", "main", "ol", "p", "pre", "section", "summary", "table", "tr", "ul",
	]

	private let bytes: [UInt8]
	private var index = 0

	private var paragraph = ""
	private var skipping: (name: String, depth: Int)?

	private(set) var title: String?
	private(set) var blocks: [String] = []
	private(set) var articles = Region()
	private(set) var mains = Region()

	init(html: String) {
		bytes = Array(html.utf8)
	}

	mutating func run() {
		while index < bytes.count {
			if bytes[index] != UInt8(ascii: "<") {
				let end = bytes[index...].firstIndex(of: UInt8(ascii: "<")) ?? bytes.count
				if skipping == nil {
					paragraph += HTMLEntities.decoded(string(index ..< end))
				}
				index = end
			} else if starts(with: "<!--") {
				index = position(after: "-->", from: index + 4) ?? bytes.count
			} else if let tag = readTag() {
				handle(tag)
			} else {
				// A "<" that doesn't open a tag, like "a < b"
				if skipping == nil {
					paragraph += "<"
				}
				index += 1
			}
		}
		endParagraph()
		articles.finish(at: blocks.count)
		mains.finish(at: blocks.count)
	}

	// MARK: - Tags

	private struct Tag {
		let name: String
		let isClosing: Bool
		let isSelfClosing: Bool
	}

	/// Reads the tag at `index` and moves past it. Quotes are followed, since an attribute's value can hold a ">".
	private mutating func readTag() -> Tag? {
		var cursor = index + 1
		guard cursor < bytes.count else { return nil }

		// <!doctype> and <?xml?> are tags with no name worth keeping
		if bytes[cursor] == UInt8(ascii: "!") || bytes[cursor] == UInt8(ascii: "?") {
			index = position(after: ">", from: cursor) ?? bytes.count
			return Tag(name: "", isClosing: false, isSelfClosing: true)
		}

		let isClosing = bytes[cursor] == UInt8(ascii: "/")
		if isClosing {
			cursor += 1
		}

		let nameStart = cursor
		while cursor < bytes.count, isNameByte(bytes[cursor]) {
			cursor += 1
		}
		guard cursor > nameStart else { return nil }
		let name = string(nameStart ..< cursor).lowercased()

		var quote: UInt8?
		while cursor < bytes.count {
			let byte = bytes[cursor]
			if let open = quote {
				if byte == open {
					quote = nil
				}
			} else if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
				quote = byte
			} else if byte == UInt8(ascii: ">") {
				break
			}
			cursor += 1
		}

		let isSelfClosing = cursor > 0 && cursor < bytes.count && bytes[cursor - 1] == UInt8(ascii: "/")
		index = min(cursor + 1, bytes.count)
		return Tag(name: name, isClosing: isClosing, isSelfClosing: isSelfClosing)
	}

	private mutating func handle(_ tag: Tag) {
		if let current = skipping {
			guard tag.name == current.name, !tag.isSelfClosing else { return }
			let depth = current.depth + (tag.isClosing ? -1 : 1)
			skipping = depth == 0 ? nil : (current.name, depth)
			return
		}

		if !tag.isClosing, tag.name == "title" {
			let end = closingTag("title")
			if title == nil {
				let found = collapsed(HTMLEntities.decoded(string(index ..< end.start)))
				title = found.isEmpty ? nil : found
			}
			index = end.after
		} else if !tag.isClosing, Self.rawElements.contains(tag.name) {
			if !tag.isSelfClosing {
				index = closingTag(tag.name).after
			}
		} else if !tag.isClosing, !tag.isSelfClosing, Self.skippedElements.contains(tag.name) {
			skipping = (tag.name, 1)
		} else if tag.name == "article" {
			endParagraph()
			articles.tag(isClosing: tag.isClosing, at: blocks.count)
		} else if tag.name == "main" {
			endParagraph()
			mains.tag(isClosing: tag.isClosing, at: blocks.count)
		} else if Self.blockElements.contains(tag.name) {
			endParagraph()
		} else if tag.name == "td" || tag.name == "th" {
			paragraph += " "
		}
	}

	private mutating func endParagraph() {
		let text = collapsed(paragraph)
		paragraph = ""
		if !text.isEmpty {
			blocks.append(text)
		}
	}

	private func collapsed(_ text: String) -> String {
		text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
	}

	// MARK: - Bytes

	private func isNameByte(_ byte: UInt8) -> Bool {
		switch byte {
			case UInt8(ascii: "a") ... UInt8(ascii: "z"), UInt8(ascii: "A") ... UInt8(ascii: "Z"), UInt8(ascii: "0") ... UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: ":"):
				true
			default:
				false
		}
	}

	private func string(_ range: Range<Int>) -> String {
		String(decoding: bytes[range], as: UTF8.self)
	}

	private func starts(with text: String) -> Bool {
		bytes[index...].starts(with: text.utf8)
	}

	private func position(after text: String, from start: Int) -> Int? {
		let needle = Array(text.utf8)
		var cursor = start
		while cursor + needle.count <= bytes.count {
			if bytes[cursor] == needle[0], bytes[cursor ..< cursor + needle.count].elementsEqual(needle) {
				return cursor + needle.count
			}
			cursor += 1
		}
		return nil
	}

	/// Where `</name` starts and where its tag ends, whatever its case. The end of the page when it's never closed.
	private func closingTag(_ name: String) -> (start: Int, after: Int) {
		let needle = Array("</\(name)".utf8)
		var cursor = index
		while cursor + needle.count <= bytes.count {
			if bytes[cursor] == needle[0], bytes[cursor + 1] == needle[1] {
				let matches = zip(bytes[cursor ..< cursor + needle.count], needle).allSatisfy { lowercased($0) == $1 }
				if matches {
					let after = bytes[cursor...].firstIndex(of: UInt8(ascii: ">")).map { $0 + 1 } ?? bytes.count
					return (cursor, after)
				}
			}
			cursor += 1
		}
		return (bytes.count, bytes.count)
	}

	private func lowercased(_ byte: UInt8) -> UInt8 {
		byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z") ? byte + 32 : byte
	}
}

// MARK: - Entities

enum HTMLEntities {
	private static let named: [Substring: String] = [
		"amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
		"ndash": "–", "mdash": "—", "hellip": "…", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
		"laquo": "«", "raquo": "»", "middot": "·", "bull": "•", "copy": "©", "reg": "®", "trade": "™", "shy": "",
	]

	/// `&amp;`, `&#39;` and `&#x27;` as characters. Anything it doesn't know stays as written.
	static func decoded(_ text: String) -> String {
		guard text.contains("&") else { return text }

		var result = ""
		var rest = text[...]
		while let ampersand = rest.firstIndex(of: "&") {
			result += rest[..<ampersand]
			let after = rest[rest.index(after: ampersand)...]
			if let semicolon = after.prefix(10).firstIndex(of: ";"), let character = character(for: after[..<semicolon]) {
				result += character
				rest = after[after.index(after: semicolon)...]
			} else {
				result += "&"
				rest = after
			}
		}
		return result + rest
	}

	private static func character(for entity: Substring) -> String? {
		guard entity.first == "#" else { return named[entity] }

		let number = entity.dropFirst()
		let code = if number.first == "x" || number.first == "X" {
			UInt32(number.dropFirst(), radix: 16)
		} else {
			UInt32(number)
		}
		return code.flatMap(Unicode.Scalar.init).map { String($0) }
	}
}
