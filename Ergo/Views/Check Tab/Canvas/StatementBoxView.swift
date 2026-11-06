//
//  StatementBoxView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoTranslation
import SwiftUI

/// What a box knows about its neighbours, for its badge and for VoiceOver. Titles, not ids, since they're only ever read.
nonisolated struct BoxRelations: Equatable {
	var premises: [String] = []
	var conclusions: [String] = []

	var isConclusion: Bool {
		!premises.isEmpty
	}
}

/// How a box looks on the canvas
nonisolated enum BoxAppearance: Equatable {
	case normal
	case selected

	/// The box an arrow is being drawn from
	case connectSource

	/// While connecting, a box the arrow can't go to
	case unavailable
}

/// One claim, drawn at `CanvasLayout.boxSize` so auto layout and free-space search match what's on screen.
/// Gestures and positioning are added around it by `CanvasBox`; this view only draws, so it can be `Equatable`
/// and skip being redrawn while the canvas pans.
struct StatementBoxView: View, Equatable {
	private static let corner = 18.0

	let statement: Statement
	let letters: [String]
	let descriptors: [String]
	let relations: BoxRelations
	let verdict: BoxVerdict?
	let appearance: BoxAppearance
	let showCheck: () -> Void

	@Environment(CatalogStore.self)
	private var catalog

	static func == (left: Self, right: Self) -> Bool {
		left.statement == right.statement && left.letters == right.letters && left.descriptors == right.descriptors
			&& left.relations == right.relations && left.verdict == right.verdict && left.appearance == right.appearance
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 3) {
			Text(headline.text)
				.font(.subheadline)
				.foregroundStyle(headline.isPlaceholder ? .secondary : .primary)
				.lineLimit(2)
				.frame(maxWidth: .infinity, alignment: .leading)

			if let logicLine {
				Text(logicLine)
					.font(.caption.monospaced())
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer(minLength: 0)

			footer
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 9)
		.frame(width: CanvasLayout.boxSize.width, height: CanvasLayout.boxSize.height, alignment: .topLeading)
		// The box is a fixed size on the canvas, and zooming is how it gets bigger, so type doesn't grow with Dynamic Type
		.dynamicTypeSize(...DynamicTypeSize.large)
		.background {
			BackdropBlur(radius: 4)
				.clipShape(RoundedRectangle(cornerRadius: Self.corner))
		}
		.overlay { outline }
		.opacity(appearance == .unavailable ? 0.4 : 1)
		.contentShape(RoundedRectangle(cornerRadius: Self.corner))
	}

	// MARK: - Content

	/// The English, else the logic read back as English, else a prompt
	private var headline: (text: String, isPlaceholder: Bool) {
		let english = statement.english.trimmingCharacters(in: .whitespacesAndNewlines)
		if !english.isEmpty {
			return (english, false)
		}
		if let derived = derivedEnglish {
			return (derived, false)
		}
		if let line = statement.logicLine(letters: letters) {
			return (line, false)
		}
		return ("Empty statement", true)
	}

	private var derivedEnglish: String? {
		guard !statement.logic.isEmpty else { return nil }
		let parse = LogicParser.parse(statement.logic)
		guard parse.diagnostics.isEmpty else { return nil }
		let text = LogicEnglish.text(for: parse.argument, letters: letters, descriptors: descriptors)
		return text.isEmpty ? nil : text
	}

	/// Shown under the English; when the English is what the logic reads back as, the logic is the headline's source anyway
	private var logicLine: String? {
		guard !statement.english.isEmpty || derivedEnglish != nil else { return nil }
		return statement.logicLine(letters: letters)
	}

	private var footer: some View {
		HStack(spacing: 6) {
			if relations.isConclusion {
				Text("∴")
					.font(.callout.weight(.semibold))
					.foregroundStyle(.secondary)
			}

			if let status {
				Label(status.text, systemImage: status.symbol)
					.font(.caption2)
					.foregroundStyle(status.color)
					.lineLimit(1)
			}

			Spacer(minLength: 0)

			if let verdict {
				VerdictBadge(verdict: verdict, action: showCheck)
			}
		}
		.frame(height: 22)
	}

	/// The small line about the statement itself, apart from how it fits with the others
	private var status: (text: String, symbol: String, color: Color)? {
		if let issue = statement.currentIssues.first {
			return (issue.message, issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill", issue.severity == .error ? .red : .orange)
		}
		if statement.isLogicOutdated, !statement.logic.isEmpty {
			return ("Logic out of date", "arrow.triangle.2.circlepath", .secondary)
		}
		if !statement.english.isEmpty, statement.logic.isEmpty {
			return ("Not translated", "text.badge.xmark", .secondary)
		}
		if !statement.logic.isEmpty, !LogicParser.parse(statement.logic).diagnostics.isEmpty {
			return ("Doesn't parse", "exclamationmark.circle.fill", .orange)
		}
		return nil
	}

	// MARK: - Outline

	@ViewBuilder
	private var outline: some View {
		let shape = RoundedRectangle(cornerRadius: Self.corner)
		switch appearance {
			case .selected:
				shape.strokeBorder(Color.accentColor, lineWidth: 3)
			case .connectSource:
				shape.strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
			case .normal, .unavailable:
				shape.strokeBorder(.primary.opacity(0.18), lineWidth: 1)
		}
	}
}

// MARK: - Reading aloud

extension StatementBoxView {
	/// "All men are mortal", or what the box would say if it had any text
	static func title(of statement: Statement, letters: [String]) -> String {
		statement.englishLine ?? statement.logicLine(letters: letters) ?? "Empty statement"
	}
}
