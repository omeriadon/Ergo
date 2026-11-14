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
				AnalysisSourceText(text: text, annotations: thing.annotations, isOpen: thing.opensText)
			}

			if thing.isUnassessed {
				Text("Not assessed")
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier("analysis.notAssessed")
			}

			ForEach(thing.annotations) { annotation in
				AnalysisAnnotationView(annotation: annotation)
					// What a highlight in the source's text scrolls to
					.id(annotation.id)
			}
		}
		.padding(14)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
	}
}

/// A highlight in a source's text, which goes to the finding it quotes. `AnalysisContent` handles it.
enum AnalysisFindingLink {
	private static let scheme = "ergo-finding"

	static func url(for annotation: BoardAnnotation.ID) -> URL {
		// Always a valid URL: a fixed scheme and an id
		URL(string: "\(scheme):\(annotation.uuidString)")!
	}

	static func annotation(in url: URL) -> BoardAnnotation.ID? {
		guard url.scheme == scheme else { return nil }
		return UUID(uuidString: String(url.absoluteString.dropFirst(scheme.count + 1)))
	}
}

/// A text source's words, with what the annotations quote marked. Tapping a mark goes to its finding. One whose quote
/// can't be found here is still listed below, just without a mark.
struct AnalysisSourceText: View {
	let text: String
	let annotations: [BoardAnnotation]

	@State private var isOpen: Bool

	init(text: String, annotations: [BoardAnnotation], isOpen: Bool) {
		self.text = text
		self.annotations = annotations
		_isOpen = State(initialValue: isOpen)
	}

	private var marked: AttributedString {
		var result = AttributedString(text)
		for annotation in annotations {
			guard let quote = annotation.quote, let range = BoardQuote.range(of: quote, in: text), let found = Range(range, in: result) else { continue }
			result[found].backgroundColor = Color.accent.opacity(0.25)
			result[found].link = AnalysisFindingLink.url(for: annotation.id)
		}
		return result
	}

	var body: some View {
		DisclosureGroup("Text", isExpanded: $isOpen) {
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

			if let objection = annotation.objection {
				AnalysisObjectionView(annotation: annotation, objection: objection)
			}
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

			if annotation.isKey {
				Label("Key", systemImage: "star.fill")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.orange)
					.accessibilityLabel("One of the findings that matter most")
			}
		}
	}
}

/// The strongest objection the analysis found, which the person can put on the board as a card of its own
struct AnalysisObjectionView: View {
	let annotation: BoardAnnotation
	let objection: String

	@Environment(BoardStore.self)
	private var boardStore

	/// Worked out from the board, so it's still right after the sheet closes or the card goes
	private var isOnBoard: Bool {
		boardStore.board(annotation.board)?.statements.contains { $0.english == objection } == true
	}

	/// Beside the card it's about, or the premise of the arrow it's about
	private var near: Statement.ID? {
		switch annotation.target {
			case let .statement(id): id
			case let .link(id): boardStore.board(annotation.board)?.links.first { $0.id == id }?.premise
			case .source: nil
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Label("Objection", systemImage: "exclamationmark.bubble")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)

			Text(objection)
				.font(.callout)
				.textSelection(.enabled)

			if isOnBoard {
				Label("On the board", systemImage: "checkmark")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else if boardStore.canEdit(annotation.board) {
				Button("Add to Board", systemImage: "plus") {
					boardStore.apply(.addCard(id: UUID(), english: objection, near: near), to: annotation.board)
				}
				.buttonStyle(.glass)
				.accessibilityIdentifier("analysis.addObjection.\(annotation.id.uuidString)")
			}
		}
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
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
