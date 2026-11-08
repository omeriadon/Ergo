//
//  LogicAnalysisRows.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

/// An icon, a compiler-style title and an optional note, used by both boxes on the Logic tab
struct MessageRow<Extra: View>: View {
	let symbol: String
	let color: Color
	let title: String
	var detail: String?
	var action: (() -> Void)?
	@ViewBuilder var extra: Extra

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if let action {
				Button(action: action) {
					header(showsChevron: true)
				}
				.buttonStyle(.plain)
			} else {
				header(showsChevron: false)
			}

			extra
				.padding(.leading, 32)
		}
	}

	private func header(showsChevron: Bool) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			Image(systemName: symbol)
				.foregroundStyle(color)
				.frame(width: 22)

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.headline)

				if let detail {
					Text(detail)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			}

			Spacer(minLength: 0)

			if showsChevron {
				Image(systemName: "chevron.right")
					.font(.footnote.weight(.semibold))
					.foregroundStyle(.tertiary)
			}
		}
		.contentShape(Rectangle())
	}
}

extension MessageRow where Extra == EmptyView {
	init(symbol: String, color: Color, title: String, detail: String? = nil, action: (() -> Void)? = nil) {
		self.init(symbol: symbol, color: color, title: title, detail: detail, action: action) {
			EmptyView()
		}
	}
}

/// Each statement next to whether it's true, for the letters in the failure line
struct CounterexampleView: View {
	let premises: [String]
	let conclusion: String?

	var body: some View {
		Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
			ForEach(Array(premises.prefix(4).enumerated()), id: \.offset) { _, premise in
				row(premise, isTrue: true)
			}

			if let conclusion {
				row(conclusion, isTrue: false)
			}
		}
	}

	private func row(_ statement: String, isTrue: Bool) -> some View {
		GridRow {
			Text(statement)
				.font(.callout.monospaced())
				.lineLimit(1)
				.truncationMode(.middle)

			Label(isTrue ? "true" : "false", systemImage: isTrue ? "checkmark" : "xmark")
				.font(.callout)
				.foregroundStyle(isTrue ? .green : .red)
		}
	}
}
