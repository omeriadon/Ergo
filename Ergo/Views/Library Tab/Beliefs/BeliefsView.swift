//
//  BeliefsView.swift
//  Ergo
//
//  Created by Adon Omeri on 16/11/2026.
//

import Defaults
import ErgoCatalog
import SwiftUI

/// The question sets and the person's beliefs, and a set being taken one question at a time. Pushed as
/// `LibraryRoute.beliefs`, so it's the same page in both layouts.
struct BeliefsView: View {
	static let symbol = "scale.3d"

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@Default(.beliefs) private var ledger

	/// Answers are saved as they're given, so leaving part way only loses the place, and the set picks up at its first
	/// unanswered question next time
	@State private var session: BeliefSession?

	var body: some View {
		content
			.navigationTitle(session?.set.title ?? "Beliefs")
			.navigationBarTitleDisplayMode(.inline)
			.animation(reduceMotion ? nil : .smooth, value: session == nil)
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					if session == nil {
						Button("New Belief", systemImage: "plus") {
							navigation.presentSheet(.newBelief)
						}
						.accessibilityIdentifier("beliefs.new")
					} else {
						Button("Stop", systemImage: "xmark") {
							session = nil
						}
						.accessibilityIdentifier("beliefs.stop")
					}
				}
			}
	}

	@ViewBuilder
	private var content: some View {
		if let session {
			if let question = session.current {
				BeliefQuestionView(
					question: question,
					set: session.set,
					progress: (session.index - session.startIndex, session.set.questions.count - session.startIndex),
					previous: ledger.belief(answering: question.id),
					answer: answer
				)
				.id(question.id)
			} else {
				BeliefSummaryView(session: session) {
					self.session = nil
				}
			}
		} else {
			BeliefsListView(start: start)
		}
	}

	private func start(_ set: BeliefQuestionSet, fromStart: Bool) {
		session = BeliefSession(set: set, startIndex: fromStart ? 0 : ledger.startIndex(of: set))
	}

	private func answer(_ confidence: Int?) {
		guard var current = session, let question = current.current else { return }
		let previous = ledger.belief(answering: question.id)
		current.record(BeliefSession.Answer(question: question, wasAnswered: previous != nil, before: previous?.confidence, after: confidence))
		ledger.answer(question, confidence: confidence)
		session = current
	}
}

/// A set being taken: where it started, where it's got to, and what's been answered so far
struct BeliefSession: Hashable {
	struct Answer: Hashable {
		let question: BeliefQuestion

		/// Whether it had been answered before, so a first answer isn't shown as a change
		let wasAnswered: Bool
		let before: Int?
		let after: Int?

		var hasMoved: Bool {
			wasAnswered && before != after
		}
	}

	let set: BeliefQuestionSet
	let startIndex: Int
	private(set) var index: Int
	private(set) var answers: [Answer] = []

	init(set: BeliefQuestionSet, startIndex: Int) {
		self.set = set
		self.startIndex = startIndex
		index = startIndex
	}

	var current: BeliefQuestion? {
		set.questions.indices.contains(index) ? set.questions[index] : nil
	}

	mutating func record(_ answer: Answer) {
		answers.append(answer)
		index += 1
	}
}

// MARK: - The list

/// The sets, then the person's beliefs, then the archived ones
private struct BeliefsListView: View {
	let start: (BeliefQuestionSet, Bool) -> Void

	@Default(.beliefs) private var ledger

	var body: some View {
		List {
			Section {
				BeliefsHeader()
			}

			Section("Question Sets") {
				ForEach(BeliefQuestionBank.sets) { set in
					BeliefSetRow(set: set, start: start)
				}
			}

			Section("Your Beliefs") {
				if ledger.listed.isEmpty {
					Text("Your answers, and anything you write with \(Image(systemName: "plus")), show here.")
						.foregroundStyle(.secondary)
				}
				ForEach(ledger.listed) { belief in
					BeliefListRow(belief: belief)
				}
			}

			if !ledger.archived.isEmpty {
				Section("Archived") {
					ForEach(ledger.archived) { belief in
						BeliefListRow(belief: belief)
					}
				}
			}
		}
	}
}

private struct BeliefsHeader: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("What do you think?")
				.font(.title.bold())
				.fontDesign(.rounded)

			Text("Rate how likely each claim is to be true. Every answer is kept, so taking a set again shows how your mind has moved.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.padding(.vertical, 6)
	}
}

private struct BeliefSetRow: View {
	let set: BeliefQuestionSet
	let start: (BeliefQuestionSet, Bool) -> Void

	@Default(.beliefs) private var ledger

	private var answered: Int {
		ledger.answeredCount(of: set)
	}

	private var status: String {
		let count = set.questions.count
		if answered == 0 {
			return "\(count) questions"
		}
		if answered < count {
			return "\(answered) of \(count) answered"
		}
		guard let date = ledger.lastTaken(set) else { return "Answered" }
		return "Last taken \(date.formatted(date: .abbreviated, time: .omitted))"
	}

	var body: some View {
		Button {
			start(set, false)
		} label: {
			HStack(spacing: 14) {
				BeliefSetProgress(fraction: Double(answered) / Double(max(set.questions.count, 1)), color: HexColor.color(set.color))

				VStack(alignment: .leading, spacing: 3) {
					Text(set.title)
						.font(.headline)
					Text(set.summary)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.lineLimit(2)
					Text(status)
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Spacer(minLength: 0)

				Image(systemName: "chevron.right")
					.foregroundStyle(.secondary)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.contextMenu {
			if answered > 0 {
				Button("Start Again", systemImage: "arrow.counterclockwise") {
					start(set, true)
				}
			}
		}
		.accessibilityIdentifier("beliefs.set.\(set.id)")
	}
}

/// How much of a set is answered, as a ring in its colour
private struct BeliefSetProgress: View {
	let fraction: Double
	let color: Color

	var body: some View {
		ZStack {
			Circle()
				.stroke(color.opacity(0.25), lineWidth: 5)
			Circle()
				.trim(from: 0, to: fraction)
				.stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
				.rotationEffect(.degrees(-90))
		}
		.frame(width: 30, height: 30)
		.accessibilityHidden(true)
	}
}

private struct BeliefListRow: View {
	let belief: Belief

	@Default(.beliefs) private var ledger

	var body: some View {
		NavigationLink(value: LibraryRoute.belief(belief.id)) {
			VStack(alignment: .leading, spacing: 6) {
				Text(belief.displayStatement)
					.lineLimit(3)

				BeliefConfidenceLine(belief: belief)
			}
			.padding(.vertical, 2)
		}
		.swipeActions {
			Button(role: .destructive) {
				ledger.delete(belief.id)
			} label: {
				Label("Delete", systemImage: "trash")
			}

			Button {
				ledger.setArchived(!belief.isArchived, belief.id)
			} label: {
				Label(belief.isArchived ? "Unarchive" : "Archive", systemImage: belief.isArchived ? "tray.and.arrow.up" : "archivebox")
			}
			.tint(.indigo)
		}
	}
}

/// How sure, as words and a bar, which way the last rating moved, and the set it came from
struct BeliefConfidenceLine: View {
	let belief: Belief

	private var set: BeliefQuestionSet? {
		belief.question.flatMap(BeliefQuestionBank.set(containing:))
	}

	private var color: Color {
		set.map { HexColor.color($0.color) } ?? .accentColor
	}

	var body: some View {
		HStack(spacing: 8) {
			if let confidence = belief.confidence {
				Gauge(value: Double(confidence), in: 0 ... 100) {
					EmptyView()
				}
				.gaugeStyle(.accessoryLinearCapacity)
				.tint(color)
				.frame(width: 60)

				Text(BeliefScale.words(for: confidence))
			} else {
				Text("No view")
			}

			BeliefMoveArrow(from: belief.previousConfidence, to: belief.confidence, hasHistory: belief.changes.count > 1)

			Spacer(minLength: 0)

			if let set {
				Text(set.title)
					.foregroundStyle(color)
			}
		}
		.font(.caption)
		.foregroundStyle(.secondary)
	}
}

/// Up or down when a rating moved, nothing for a first one
struct BeliefMoveArrow: View {
	let from: Int?
	let to: Int?
	let hasHistory: Bool

	var body: some View {
		if hasHistory, let from, let to, from != to {
			Image(systemName: to > from ? "arrow.up.right" : "arrow.down.right")
				.accessibilityLabel(to > from ? "More sure than before" : "Less sure than before")
		}
	}
}
