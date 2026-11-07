//
//  MarkdownDocumentTests.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoMarkdown
import Foundation
import Testing

struct MarkdownDocumentTests {
	private func text(_ attributed: AttributedString) -> String {
		String(attributed.characters)
	}

	@Test func headingsAndParagraphs() {
		let blocks = MarkdownDocument("# Title\n\nSome **bold** words.\n\nMore.").blocks
		#expect(blocks.count == 3)
		guard case let .heading(level, title) = blocks[0], case let .paragraph(body) = blocks[1] else {
			Issue.record("Expected a heading and a paragraph, found \(blocks)")
			return
		}
		#expect(level == 1)
		#expect(text(title) == "Title")
		#expect(text(body) == "Some bold words.")
		#expect(body.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
	}

	@Test func linksSurvive() throws {
		let url = "ergo://intent/open-library-entry?category=fallacies&id=straw-man"
		let blocks = MarkdownDocument("That's a [straw man](\(url)).").blocks
		guard case let .paragraph(body) = try #require(blocks.first) else {
			Issue.record("Expected a paragraph")
			return
		}
		#expect(body.runs.compactMap(\.link).first?.absoluteString == url)
	}

	@Test func codeBlocksKeepTheirLines() {
		let blocks = MarkdownDocument("```swift\nlet a = 1\nlet b = 2\n```").blocks
		#expect(blocks == [.code(language: "swift", text: "let a = 1\nlet b = 2")])
	}

	@Test func listsNestAndKeepTheirOrder() {
		let blocks = MarkdownDocument("1. one\n2. two\n   - inner\n3. three").blocks
		guard case let .list(ordered, items) = blocks.first else {
			Issue.record("Expected a list, found \(blocks)")
			return
		}
		#expect(ordered)
		#expect(items.count == 3)
		#expect(items[1].count == 2)
		guard case let .list(innerOrdered, inner) = items[1][1] else {
			Issue.record("Expected a nested list, found \(items[1])")
			return
		}
		#expect(!innerOrdered)
		#expect(inner.count == 1)
	}

	@Test func quotesHoldBlocks() {
		let blocks = MarkdownDocument("> quoted\n>\n> again").blocks
		guard case let .quote(inner) = blocks.first else {
			Issue.record("Expected a quote, found \(blocks)")
			return
		}
		#expect(inner.count == 2)
	}

	@Test func tablesHaveAHeaderAndRows() {
		let blocks = MarkdownDocument("| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |").blocks
		guard case let .table(header, rows) = blocks.first else {
			Issue.record("Expected a table, found \(blocks)")
			return
		}
		#expect(header.map(text) == ["a", "b"])
		#expect(rows.map { $0.map(text) } == [["1", "2"], ["3", "4"]])
	}

	@Test func rules() {
		let blocks = MarkdownDocument("above\n\n---\n\nbelow").blocks
		#expect(blocks.count == 3)
		#expect(blocks[1] == .rule)
	}

	@Test func textStillArrivingDoesNotBreak() {
		for partial in ["**bo", "[a link](ergo://int", "```swi", "| a | b", "1. "] {
			_ = MarkdownDocument(partial).blocks
		}
		#expect(MarkdownDocument("").blocks.isEmpty)
	}
}
