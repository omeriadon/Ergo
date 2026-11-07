//
//  MarkdownDocument.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

/// Markdown as blocks for a view to lay out. Foundation does the parsing, including of text that's still arriving,
/// and each block's text is an `AttributedString` that `Text` shows with its bold, italics, code and links.
public struct MarkdownDocument: Sendable, Hashable {
	public indirect enum Block: Sendable, Hashable {
		case heading(level: Int, text: AttributedString)
		case paragraph(AttributedString)
		case code(language: String?, text: String)
		case quote([Block])
		case list(ordered: Bool, items: [[Block]])
		case table(header: [AttributedString], rows: [[AttributedString]])
		case rule
	}

	public let blocks: [Block]

	public init(_ markdown: String) {
		let options = AttributedString.MarkdownParsingOptions(
			allowsExtendedAttributes: true,
			interpretedSyntax: .full,
			failurePolicy: .returnPartiallyParsedIfPossible
		)
		guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
			blocks = markdown.isEmpty ? [] : [.paragraph(AttributedString(markdown))]
			return
		}
		blocks = Self.blocks(in: Node.tree(of: parsed).children)
	}

	// MARK: - Tree

	/// A block as Foundation sees it. Every run of text names all the blocks it's inside, outermost last.
	private final class Node {
		let kind: PresentationIntent.Kind?
		let identity: Int
		var children: [Node] = []
		var text = AttributedString()

		init(kind: PresentationIntent.Kind?, identity: Int) {
			self.kind = kind
			self.identity = identity
		}

		static func tree(of parsed: AttributedString) -> Node {
			let root = Node(kind: nil, identity: -1)
			for run in parsed.runs {
				var node = root
				for component in (run.presentationIntent?.components ?? []).reversed() {
					if let last = node.children.last, last.identity == component.identity {
						node = last
					} else {
						let child = Node(kind: component.kind, identity: component.identity)
						node.children.append(child)
						node = child
					}
				}
				var text = AttributedString(parsed[run.range])
				text.presentationIntent = nil
				node.text += text
			}
			return root
		}
	}

	private static func blocks(in nodes: [Node]) -> [Block] {
		nodes.compactMap(block)
	}

	private static func block(_ node: Node) -> Block? {
		guard let kind = node.kind else { return nil }
		switch kind {
			case let .header(level):
				return .heading(level: level, text: node.text)
			case .paragraph:
				return .paragraph(node.text)
			case let .codeBlock(language):
				var code = String(node.text.characters)
				if code.hasSuffix("\n") {
					code.removeLast()
				}
				return .code(language: language, text: code)
			case .blockQuote:
				return .quote(blocks(in: node.children))
			case .orderedList:
				return .list(ordered: true, items: node.children.map { blocks(in: $0.children) })
			case .unorderedList:
				return .list(ordered: false, items: node.children.map { blocks(in: $0.children) })
			case .thematicBreak:
				return .rule
			case .table:
				return table(node)
			default:
				return nil
		}
	}

	private static func table(_ node: Node) -> Block {
		var header: [AttributedString] = []
		var rows: [[AttributedString]] = []
		for row in node.children {
			let cells = row.children.map(\.text)
			if case .tableHeaderRow = row.kind {
				header = cells
			} else {
				rows.append(cells)
			}
		}
		return .table(header: header, rows: rows)
	}
}
