//
//  PracticeView.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import Defaults
import ErgoCatalog
import ErgoLogic
import SwiftUI

/// Spaced-repetition practice over the library and the finished course lessons: what's due, then a session one card at a
/// time, then how it went. Pushed as `LibraryRoute.practice`, so it's the same page in both layouts.
struct PracticeView: View {
	static let symbol = "rectangle.stack"

	@Environment(TranslationAccount.self)
	private var account

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@Default(.practiceProgress) private var progress
	@Default(.logicCourseFinished) private var finishedLessons

	@State private var deck: PracticeDeck?
	@State private var cardsByTopic: [String: [PracticeCard]] = [:]
	@State private var loadFailed = false
	@State private var session: PracticeSession?

	private var courseLessons: [String] {
		PracticeLibrary.courseLessons(finished: finishedLessons, hasPlus: account.hasPlusFeatures).map(\.id)
	}

	var body: some View {
		content
			.navigationTitle("Practice")
			.navigationBarTitleDisplayMode(.inline)
			.animation(reduceMotion ? nil : .smooth, value: session == nil)
			.task(id: courseLessons) {
				await load()
			}
	}

	@ViewBuilder
	private var content: some View {
		if let session {
			if let question = session.current {
				PracticeQuestionView(
					question: question,
					chosen: session.chosen,
					progress: (session.answeredCount, session.count),
					choose: choose,
					next: next
				)
				.id(question)
			} else {
				PracticeSummaryView(session: session, again: { start(topic: nil) }, done: { self.session = nil })
			}
		} else if deck != nil {
			PracticeStartView(cardsByTopic: cardsByTopic, start: { start(topic: $0) })
		} else if loadFailed {
			ContentUnavailableView(
				"Practice Couldn't Load",
				systemImage: "exclamationmark.triangle",
				description: Text("error: the library's files couldn't be read")
			)
		} else {
			ProgressView()
		}
	}

	/// Only a card's first answer in a session moves it between boxes
	private func choose(_ index: Int) {
		guard var current = session, let result = current.choose(index) else { return }
		if result.isFirst, let id = current.current?.card.id {
			progress.record(id, correct: result.isCorrect, at: .now)
		}
		session = current
	}

	private func next() {
		var random = SystemRandomNumberGenerator()
		session?.next(using: &random)
	}

	private func load() async {
		let lessons = PracticeLibrary.courseLessons(finished: finishedLessons, hasPlus: account.hasPlusFeatures)
		do {
			let loaded = try await PracticeLibrary.deck(courseLessons: lessons)
			deck = loaded
			cardsByTopic = Dictionary(grouping: loaded.cards, by: \.topic)
		} catch {
			loadFailed = true
		}
	}

	/// A session over one topic, or every topic when nil
	private func start(topic: String?) {
		guard let deck else { return }
		let cards = topic.map { cardsByTopic[$0] ?? [] } ?? deck.cards
		let plan = progress.plan(cards, at: .now)
		guard !plan.isEmpty else { return }
		var random = SystemRandomNumberGenerator()
		session = PracticeSession(cards: plan, deck: deck, using: &random)
	}
}

// MARK: - Start

/// What's due, and a way in: everything at once, or one topic
private struct PracticeStartView: View {
	let cardsByTopic: [String: [PracticeCard]]
	let start: (String?) -> Void

	@Default(.practiceProgress) private var progress

	private var topics: [String] {
		PracticeLibrary.topics.filter { !(cardsByTopic[$0] ?? []).isEmpty }
	}

	var body: some View {
		List {
			Section {
				PracticeStartHeader(due: progress.dueCount(at: .now)) {
					start(nil)
				}
			}

			Section("Topics") {
				ForEach(topics, id: \.self) { topic in
					PracticeTopicRow(topic: topic, cards: cardsByTopic[topic] ?? [], start: start)
				}
			}
		}
	}
}

private struct PracticeStartHeader: View {
	let due: Int
	let start: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(due == 0 ? "Nothing due" : "\(due) due")
				.font(.title.bold())
				.fontDesign(.rounded)

			Text("Questions come from the library and the lessons you've finished. Ones you get right come back less often.")
				.font(.subheadline)
				.foregroundStyle(.secondary)

			Button(due == 0 ? "Learn Something New" : "Practise", systemImage: "play.fill", action: start)
				.buttonStyle(.glassProminent)
				.accessibilityIdentifier("practice.start")
		}
		.padding(.vertical, 6)
	}
}

private struct PracticeTopicRow: View {
	let topic: String
	let cards: [PracticeCard]
	let start: (String?) -> Void

	@Default(.practiceProgress) private var progress

	private var subtitle: String {
		let due = progress.dueCount(of: cards, at: .now)
		let new = progress.newCount(of: cards)
		return due > 0 ? "\(due) due, \(new) new" : "\(new) new"
	}

	var body: some View {
		Button {
			start(topic)
		} label: {
			HStack {
				Label {
					VStack(alignment: .leading, spacing: 2) {
						Text(PracticeLibrary.title(of: topic))
						Text(subtitle)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				} icon: {
					Image(systemName: PracticeLibrary.symbol(of: topic))
				}

				Spacer(minLength: 0)

				Image(systemName: "chevron.right")
					.foregroundStyle(.secondary)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}
