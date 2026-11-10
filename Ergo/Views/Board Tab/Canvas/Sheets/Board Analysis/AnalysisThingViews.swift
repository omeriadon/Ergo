//
//  AnalysisThingViews.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoProtocol
import ErgoSync
import SwiftUI

// MARK: - Things and their annotations

struct AnalysisGroupView: View {
	let group: AnalysisOutline.Group

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text(group.title)
				.font(.title3.bold())

			ForEach(group.things) { thing in
				AnalysisThingView(thing: thing)
			}
		}
	}
}

struct AnalysisThingView: View {
	let thing: AnalysisOutline.Thing

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(thing.heading)
				.font(.subheadline.weight(.semibold))
				.lineLimit(4)
				.frame(maxWidth: .infinity, alignment: .leading)

			if let text = thing.text {
				AnalysisSourceText(text: text, quotes: thing.annotations.compactMap(\.quote))
			}

			if thing.isUnassessed {
				Text("Not assessed")
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier("analysis.notAssessed")
			}

			ForEach(thing.annotations) { annotation in
				AnalysisAnnotationView(annotation: annotation)
			}
		}
		.padding(14)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
	}
}

/// A text source's words, with what the annotations quote marked
struct AnalysisSourceText: View {
	let text: String
	let quotes: [String]

	private var marked: AttributedString {
		var result = AttributedString(text)
		for quote in quotes {
			guard let range = BoardQuote.range(of: quote, in: text), let found = Range(range, in: result) else { continue }
			result[found].backgroundColor = Color.accent.opacity(0.25)
		}
		return result
	}

	var body: some View {
		DisclosureGroup("Text") {
			Text(marked)
				.font(.callout)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.font(.subheadline)
		.accessibilityIdentifier("analysis.sourceText")
	}
}

struct AnalysisAnnotationView: View {
	let annotation: BoardAnnotation

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(AskStore.self)
	private var store

	private var intent: AskIntent {
		.openLibraryEntry(category: annotation.citation.category, id: annotation.citation.id)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			header

			if let quote = annotation.quote {
				Text("“\(quote)”")
					.font(.callout.italic())
					.textSelection(.enabled)
					.padding(.leading, 10)
					.overlay(alignment: .leading) {
						Capsule()
							.fill(Color.accent.opacity(0.6))
							.frame(width: 3)
					}
			}

			AskMarkdownView(text: annotation.markdown)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityIdentifier("analysis.annotation.\(annotation.id.uuidString)")
	}

	private var header: some View {
		HStack(spacing: 8) {
			// Opens the entry the way a link in an answer does, which closes this sheet
			Button(annotation.citation.name, systemImage: "books.vertical") {
				AskIntents.run(intent, navigation: navigation, store: store)
			}
			.buttonStyle(.glass)
			.disabled(!AskIntents.canRun(intent))
			.accessibilityHint("Opens this entry in the Library")
			.accessibilityIdentifier("analysis.open.\(annotation.id.uuidString)")

			if let assessment = annotation.assessment {
				Text(assessment.label)
					.font(.caption.weight(.semibold))
					.padding(.horizontal, 8)
					.padding(.vertical, 4)
					.foregroundStyle(assessment.tint)
					.background(assessment.tint.opacity(0.15), in: Capsule())
			}
		}
	}
}

extension BoardAnnotation.Assessment {
	var label: String {
		switch self {
			case let .arrow(strength): strength.label
			case let .conclusion(support): support.label
		}
	}

	var tint: Color {
		switch self {
			case let .arrow(strength): strength.tint
			case let .conclusion(support): support.tint
		}
	}
}
