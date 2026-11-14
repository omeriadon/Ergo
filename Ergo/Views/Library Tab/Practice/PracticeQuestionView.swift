//
//  PracticeQuestionView.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import Defaults
import ErgoCatalog
import SwiftUI

/// One card: what it asks, its choices, and once answered, whether that was right, why, and where to read more
struct PracticeQuestionView: View {
	let question: PracticeQuestion
	let chosen: Int?
	let progress: (answered: Int, count: Int)
	let choose: (Int) -> Void
	let next: () -> Void

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@Default(.hapticsEnabled) private var hapticsEnabled

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				ProgressView(value: Double(progress.answered), total: Double(max(progress.count, 1)))

				PracticePrompt(question: question)

				PracticeChoices(question: question, chosen: chosen, choose: choose)

				if let chosen {
					PracticeFeedback(question: question, isCorrect: chosen == question.correctIndex, next: next)
						.transition(.blurReplace)
				}
			}
			.padding()
			.frame(maxWidth: 640, alignment: .leading)
			.frame(maxWidth: .infinity)
		}
		.animation(reduceMotion ? nil : .smooth, value: chosen)
		.practiceHaptic(chosen.map { $0 == question.correctIndex }, enabled: hapticsEnabled)
	}
}

private struct PracticePrompt: View {
	let question: PracticeQuestion

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Label(PracticeLibrary.title(of: question.card.topic), systemImage: PracticeLibrary.symbol(of: question.card.topic))
				.font(.subheadline)
				.foregroundStyle(.secondary)

			Text(PracticeLibrary.question(for: question.card))
				.font(.title3.bold())

			promptText
				.textSelection(.enabled)

			if let detail = question.card.detail {
				Text(detail)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
		}
	}

	@ViewBuilder
	private var promptText: some View {
		switch question.card.kind {
			case .define:
				Text(question.prompt)
					.font(.title.bold())
					.fontDesign(.rounded)
			case .validity:
				Text(question.prompt)
					.font(.title3.monospaced())
					.minimumScaleFactor(0.6)
					.lineLimit(1)
			case .identify:
				Text(question.prompt)
					.padding(14)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
		}
	}
}

private struct PracticeChoices: View {
	let question: PracticeQuestion
	let chosen: Int?
	let choose: (Int) -> Void

	var body: some View {
		VStack(spacing: 8) {
			ForEach(question.choices.indices, id: \.self) { index in
				PracticeChoiceButton(
					text: question.choices[index],
					mark: mark(for: index),
					action: { choose(index) }
				)
				.accessibilityIdentifier("practice.choice.\(index)")
			}
		}
		.allowsHitTesting(chosen == nil)
	}

	private func mark(for index: Int) -> PracticeChoiceButton.Mark {
		guard let chosen else { return .none }
		if index == question.correctIndex {
			return .right
		}
		return index == chosen ? .wrong : .none
	}
}

private struct PracticeChoiceButton: View {
	enum Mark {
		case none, right, wrong
	}

	let text: String
	let mark: Mark
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(alignment: .firstTextBaseline, spacing: 10) {
				Text(text)
					.multilineTextAlignment(.leading)
					.frame(maxWidth: .infinity, alignment: .leading)

				switch mark {
					case .none:
						EmptyView()
					case .right:
						Image(systemName: "checkmark.circle.fill")
							.foregroundStyle(.green)
							.accessibilityLabel("Right answer")
					case .wrong:
						Image(systemName: "xmark.circle.fill")
							.foregroundStyle(.orange)
							.accessibilityLabel("Your answer")
				}
			}
			.padding(.vertical, 4)
			.contentShape(Rectangle())
		}
		.buttonStyle(.glass)
	}
}

private struct PracticeFeedback: View {
	let question: PracticeQuestion
	let isCorrect: Bool
	let next: () -> Void

	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Label(isCorrect ? "Right" : "Not quite", systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
				.font(.headline)
				.foregroundStyle(isCorrect ? .green : .orange)

			if !isCorrect, question.card.kind != .define {
				Text("It's \(question.answer).")
					.font(.subheadline.weight(.semibold))
			}

			if let explanation = question.card.explanation {
				Text(explanation)
					.font(.subheadline)
			}

			HStack {
				Button(sourceTitle, systemImage: "arrow.up.right", action: openSource)
					.buttonStyle(.glass)

				Spacer(minLength: 0)

				Button("Next", systemImage: "arrow.right", action: next)
					.buttonStyle(.glassProminent)
					.keyboardShortcut(.defaultAction)
					.accessibilityIdentifier("practice.next")
			}
			.padding(.top, 4)
		}
	}

	private var sourceTitle: String {
		switch question.card.source {
			case .library:
				"Open \(question.card.title)"
			case .lesson:
				"Open Lesson"
		}
	}

	private func openSource() {
		switch question.card.source {
			case let .library(category, id):
				if let category = LibraryContent(rawValue: category) {
					navigation.openLibraryEntry(category: category, id: id)
				}
			case let .lesson(id):
				navigation.reveal(.logic)
				navigation.logicPath = [.course, .lesson(id)]
		}
	}
}

// MARK: - Summary

/// How the session went: first answers right, and what to look at again
struct PracticeSummaryView: View {
	let session: PracticeSession
	let again: () -> Void
	let done: () -> Void

	@Default(.practiceProgress) private var progress

	var body: some View {
		ContentUnavailableView {
			Label("\(session.correctCount) of \(session.answeredCount) Right", systemImage: "checkmark.seal")
		} description: {
			Text(description)
		} actions: {
			Button("Done", action: done)
				.buttonStyle(.glassProminent)
				.accessibilityIdentifier("practice.done")

			if progress.dueCount(at: .now) > 0 {
				Button("Keep Practising", action: again)
					.buttonStyle(.glass)
			}
		}
	}

	private var description: String {
		let missed = session.answeredCount - session.correctCount
		if missed == 0 {
			return "Every card right first time. They'll come back later than before."
		}
		return missed == 1
			? "The one you missed comes back tomorrow."
			: "The \(missed) you missed come back tomorrow."
	}
}

// MARK: - Haptics

extension View {
	/// A success or error tap when a card is answered. iOS only, and only when haptics are on.
	func practiceHaptic(_ isCorrect: Bool?, enabled: Bool) -> some View {
		#if os(iOS)
			sensoryFeedback(trigger: isCorrect) { _, new in
				guard enabled, let new else { return nil }
				return new ? .success : .error
			}
		#else
			self
		#endif
	}
}
