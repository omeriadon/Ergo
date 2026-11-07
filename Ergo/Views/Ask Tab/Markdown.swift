//
//  Markdown.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoMarkdown
import SwiftUI

/// An answer's markdown. It's parsed again each time more arrives, which is what lets text that's still being written
/// show properly formatted. Runs of text are one selectable view, with code and tables in views of their own between them.
struct AskMarkdownView: View {
	private enum Part {
		case text([MarkdownDocument.Block])
		case code(language: String?, code: String)
		case table(header: [AttributedString], rows: [[AttributedString]])
		case rule
	}

	let text: String

	private var parts: [Part] {
		var parts: [Part] = []
		var run: [MarkdownDocument.Block] = []

		func endRun() {
			if !run.isEmpty {
				parts.append(.text(run))
				run = []
			}
		}

		for block in MarkdownDocument(text).blocks {
			switch block {
				case let .code(language, code):
					endRun()
					parts.append(.code(language: language, code: code))
				case let .table(header, rows):
					endRun()
					parts.append(.table(header: header, rows: rows))
				case .rule:
					endRun()
					parts.append(.rule)
				default:
					run.append(block)
			}
		}
		endRun()
		return parts
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
				switch part {
					case let .text(blocks):
						AskSelectableText(blocks: blocks)
					case let .code(language, code):
						AskCodeBlock(language: language, code: code)
					case let .table(header, rows):
						AskMarkdownTable(header: header, rows: rows)
					case .rule:
						Divider()
				}
			}
		}
	}
}

private struct AskMarkdownTable: View {
	let header: [AttributedString]
	let rows: [[AttributedString]]

	/// Table cells are SwiftUI's own `Text`, so maths gets the same look through its attributes
	private func styled(_ cell: AttributedString) -> AttributedString {
		var cell = cell
		for run in cell.runs {
			if let script = run[MarkdownMathAttribute.self] {
				cell[run.range].font = .custom("CourierNewPS-BoldMT", size: script == 0 ? 15 : 11, relativeTo: .subheadline)
				if script != 0 {
					cell[run.range].baselineOffset = script > 0 ? 5 : -3
				}
			}
			if let url = run.link, !AskMarkdownLinks.canOpen(url) {
				cell[run.range].link = nil
			}
		}
		return cell
	}

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
				GridRow {
					ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
						Text(styled(cell))
							.font(.subheadline.bold())
					}
				}

				Divider()

				ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
					GridRow {
						ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
							Text(styled(cell))
								.font(.subheadline)
						}
					}
				}
			}
			.textSelection(.enabled)
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

				AskCopyButton(text: code)
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

// MARK: - Copying

/// Blurs into a checkmark for a moment after copying, so it's clear it worked
struct AskCopyButton: View {
	let text: String

	@State private var copied = false
	@State private var resetting: Task<Void, Never>?

	var body: some View {
		Button(action: copy) {
			// Toolbar-style buttons don't pick up an animation from outside, so it's kept right here
			ZStack {
				let symbol = copied ? "checkmark" : "doc.on.doc"
				Image(systemName: symbol)
					.id(symbol)
					.transition(.blurReplace)
			}
			.animation(.smooth, value: copied)
		}
		.font(.footnote)
		.foregroundStyle(.secondary)
		.accessibilityLabel(copied ? "Copied" : "Copy")
	}

	private func copy() {
		UIPasteboard.general.string = text
		copied = true

		resetting?.cancel()
		resetting = Task {
			try? await Task.sleep(for: .seconds(2))
			guard !Task.isCancelled else { return }
			copied = false
		}
	}
}
