//
//  StatementBoxView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoSync
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
	static let corner = 18.0

	let statement: Statement
	let relations: BoxRelations
	let appearance: BoxAppearance
	var annotationCount = 0
	var support: BoardConclusionSupport?
	var comment: BoardAnalysisComment?
	var findHighlight: String?

	static func == (left: Self, right: Self) -> Bool {
		left.statement == right.statement && left.relations == right.relations && left.appearance == right.appearance
			&& left.annotationCount == right.annotationCount && left.support == right.support && left.comment == right.comment
			&& left.findHighlight == right.findHighlight
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 3) {
			Text(AttributedString(headline.text).findHighlighted(headline.isPlaceholder ? nil : findHighlight))
				.font(.subheadline)
				.foregroundStyle(headline.isPlaceholder ? .secondary : .primary)
				.lineLimit(2)
				.frame(maxWidth: .infinity, alignment: .leading)

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
				.overlay(support?.tint.opacity(0.12) ?? .clear)
				.clipShape(RoundedRectangle(cornerRadius: Self.corner))
		}
		.overlay { outline }
		.overlay(alignment: .topLeading) { CanvasCommentOverlay(comment: comment) }
		.opacity(appearance == .unavailable ? 0.4 : 1)
		.contentShape(RoundedRectangle(cornerRadius: Self.corner))
		.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Self.corner))
	}

	// MARK: - Content

	/// The English, else a prompt
	private var headline: (text: String, isPlaceholder: Bool) {
		let english = statement.english.trimmingCharacters(in: .whitespacesAndNewlines)
		return english.isEmpty ? ("Empty statement", true) : (english, false)
	}

	private var footer: some View {
		HStack(spacing: 6) {
			if relations.isConclusion {
				Text("∴")
					.font(.callout.weight(.semibold))
					.foregroundStyle(.secondary)
			}

			if let support {
				Image(systemName: support.symbol)
					.font(.caption.weight(.semibold))
					.foregroundStyle(support.tint)
			}

			Spacer(minLength: 0)

			AnnotationBadge(count: annotationCount)
		}
		.frame(height: 22)
	}

	// MARK: - Outline

	@ViewBuilder
	private var outline: some View {
		let shape = RoundedRectangle(cornerRadius: Self.corner)
		switch appearance {
			case .selected:
				shape.strokeBorder(Color.accent, lineWidth: 3)
			case .connectSource:
				shape.strokeBorder(Color.accent, style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
			case .normal, .unavailable:
				if let support {
					shape.strokeBorder(support.tint, lineWidth: 2)
				} else {
					shape.strokeBorder(.primary.opacity(0.18), lineWidth: 1)
				}
		}
	}
}

// MARK: - Annotations

/// How many annotations the analysis has on a box. It sits in the footer's spare room, so the box keeps its size.
struct AnnotationBadge: View {
	let count: Int

	var body: some View {
		if count > 0 {
			Label("\(count)", systemImage: "text.magnifyingglass")
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.tint)
				.padding(.horizontal, 7)
				.padding(.vertical, 3)
				.background(Color.accent.opacity(0.15), in: Capsule())
		}
	}
}

// MARK: - Reading aloud

extension StatementBoxView {
	/// "All men are mortal", or what the box would say if it had any text
	static func title(of statement: Statement) -> String {
		statement.englishLine ?? "Empty statement"
	}
}
