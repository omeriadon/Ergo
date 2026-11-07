//
//  AskMarkdownView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoMarkdown
import ErgoProtocol
import SwiftUI

/// An answer's markdown, laid out block by block. It's parsed again each time more arrives, which is what lets text
/// that's still being written show properly formatted.
struct AskMarkdownView: View {
	let text: String

	var body: some View {
		AskMarkdownBlocks(blocks: MarkdownDocument(text).blocks)
	}
}

private struct AskMarkdownBlocks: View {
	let blocks: [MarkdownDocument.Block]

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
				AskMarkdownBlock(block: block)
			}
		}
	}
}

private struct AskMarkdownBlock: View {
	let block: MarkdownDocument.Block

	var body: some View {
		switch block {
			case let .heading(level, text):
				AskInlineText(text: text)
					.font(Self.font(level: level))
					.padding(.top, 4)
					.accessibilityAddTraits(.isHeader)

			case let .paragraph(text):
				AskInlineText(text: text)

			case let .code(language, text):
				AskCodeBlock(language: language, code: text)

			case let .quote(blocks):
				AskMarkdownBlocks(blocks: blocks)
					.foregroundStyle(.secondary)
					.padding(.leading, 12)
					.overlay(alignment: .leading) {
						Capsule()
							.fill(.tertiary)
							.frame(width: 3)
					}

			case let .list(ordered, items):
				AskMarkdownList(ordered: ordered, items: items)

			case let .table(header, rows):
				AskMarkdownTable(header: header, rows: rows)

			case .rule:
				Divider()
		}
	}

	private static func font(level: Int) -> Font {
		switch level {
			case 1: .title2.bold()
			case 2: .title3.bold()
			default: .headline
		}
	}
}

/// Links this app can't follow lose their link and stay as words, since the server's library can be newer than this one
private struct AskInlineText: View {
	let text: AttributedString

	private var checked: AttributedString {
		var checked = text
		for run in text.runs {
			guard let url = run.link, let intent = AskIntent(url: url), !AskIntents.canRun(intent) else { continue }
			checked[run.range].link = nil
		}
		return checked
	}

	var body: some View {
		Text(checked)
			.fixedSize(horizontal: false, vertical: true)
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}

private struct AskMarkdownList: View {
	let ordered: Bool
	let items: [[MarkdownDocument.Block]]

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			ForEach(Array(items.enumerated()), id: \.offset) { index, item in
				HStack(alignment: .firstTextBaseline, spacing: 8) {
					Text(ordered ? "\(index + 1)." : "•")
						.foregroundStyle(.secondary)
						.monospacedDigit()

					AskMarkdownBlocks(blocks: item)
				}
			}
		}
	}
}

private struct AskMarkdownTable: View {
	let header: [AttributedString]
	let rows: [[AttributedString]]

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
				GridRow {
					ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
						Text(cell)
							.font(.subheadline.bold())
					}
				}

				Divider()

				ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
					GridRow {
						ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
							Text(cell)
								.font(.subheadline)
						}
					}
				}
			}
			.padding(12)
		}
		.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
	}
}

private struct AskCodeBlock: View {
	let language: String?
	let code: String

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				if let language, !language.isEmpty {
					Text(language)
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Spacer()

				Button("Copy", systemImage: "doc.on.doc") {
					UIPasteboard.general.string = code
				}
				.labelStyle(.iconOnly)
				.font(.caption)
				.foregroundStyle(.secondary)
			}

			ScrollView(.horizontal, showsIndicators: false) {
				Text(code)
					.font(.callout.monospaced())
					.textSelection(.enabled)
			}
		}
		.padding(12)
		.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
	}
}
