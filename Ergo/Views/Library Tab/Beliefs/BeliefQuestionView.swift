//
//  BeliefQuestionView.swift
//  Ergo
//
//  Created by Adon Omeri on 16/11/2026.
//

import Defaults
import ErgoCatalog
import SwiftUI

/// One question of a set: the claim, the slider, and what was answered last time
struct BeliefQuestionView: View {
	let question: BeliefQuestion
	let set: BeliefQuestionSet
	let progress: (answered: Int, count: Int)
	let previous: Belief?
	let answer: (Int?) -> Void

	@State private var value: Double

	init(question: BeliefQuestion, set: BeliefQuestionSet, progress: (answered: Int, count: Int), previous: Belief?, answer: @escaping (Int?) -> Void) {
		self.question = question
		self.set = set
		self.progress = progress
		self.previous = previous
		self.answer = answer
		_value = State(initialValue: Double(previous?.confidence ?? BeliefScale.middle))
	}

	private var color: Color {
		HexColor.color(set.color)
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				ProgressView(value: Double(progress.answered), total: Double(max(progress.count, 1)))
					.tint(color)

				Text(question.statement)
					.font(.title2.bold())
					.fontDesign(.rounded)
					.textSelection(.enabled)

				VStack(alignment: .leading, spacing: 10) {
					BeliefSlider(value: $value, color: color)

					if let previous {
						Text("Last time: \(previous.confidence.map(BeliefScale.words) ?? "No view")")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}

				BeliefQuestionButtons(
					noView: { answer(nil) },
					next: { answer(BeliefScale.snapped(value)) }
				)
			}
			.padding()
			.frame(maxWidth: 640, alignment: .leading)
			.frame(maxWidth: .infinity)
		}
	}
}

private struct BeliefQuestionButtons: View {
	let noView: () -> Void
	let next: () -> Void

	var body: some View {
		HStack {
			Button("No View", action: noView)
				.buttonStyle(.glass)
				.accessibilityIdentifier("beliefs.noView")

			Spacer(minLength: 0)

			Button("Next", systemImage: "arrow.right", action: next)
				.buttonStyle(.glassProminent)
				.keyboardShortcut(.defaultAction)
				.accessibilityIdentifier("beliefs.next")
		}
	}
}

/// How sure, 0 to 100 in steps of 10, with the words for where it sits
struct BeliefSlider: View {
	@Binding var value: Double
	let color: Color
	var onEditingChanged: (Bool) -> Void = { _ in }

	@Default(.hapticsEnabled) private var hapticsEnabled

	private var confidence: Int {
		BeliefScale.snapped(value)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(alignment: .firstTextBaseline) {
				Text(BeliefScale.words(for: confidence))
					.font(.headline)
					.contentTransition(.opacity)

				Spacer(minLength: 0)

				Text("\(confidence)%")
					.font(.subheadline.monospacedDigit())
					.foregroundStyle(.secondary)
			}

			Slider(value: $value, in: 0 ... 100, step: Double(BeliefScale.step), onEditingChanged: onEditingChanged) {
				Text("How likely it is to be true")
			}
			.tint(color)
			.accessibilityValue("\(BeliefScale.words(for: confidence)), \(confidence) percent")
			.sensoryFeedback(.selection, trigger: confidence) { _, _ in hapticsEnabled }
		}
	}
}

// MARK: - Summary

/// What was answered this time, what moved since last time, and where to read more
struct BeliefSummaryView: View {
	let session: BeliefSession
	let done: () -> Void

	private var moved: Int {
		session.answers.count(where: \.hasMoved)
	}

	private var entries: [String] {
		var seen: Set<String> = []
		return session.answers.flatMap(\.question.entries).filter { seen.insert($0).inserted }
	}

	var body: some View {
		List {
			Section {
				BeliefSummaryHeader(answered: session.answers.count, moved: moved, isRetake: session.answers.contains(where: \.wasAnswered), done: done)
			}

			Section("Your Answers") {
				ForEach(session.answers, id: \.question.id) { answer in
					BeliefSummaryRow(answer: answer)
				}
			}

			if !entries.isEmpty {
				Section("Read More") {
					BeliefEntryLinks(entries: entries)
				}
			}
		}
	}
}

private struct BeliefSummaryHeader: View {
	let answered: Int
	let moved: Int
	let isRetake: Bool
	let done: () -> Void

	private var detail: String {
		guard isRetake else { return "Take the set again whenever you like, and see what's changed." }
		switch moved {
			case 0:
				return "Nothing moved since last time."
			case 1:
				return "1 answer moved since last time."
			default:
				return "\(moved) answers moved since last time."
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("^[\(answered) answer](inflect: true)")
				.font(.title.bold())
				.fontDesign(.rounded)

			Text(detail)
				.font(.subheadline)
				.foregroundStyle(.secondary)

			Button("Done", action: done)
				.buttonStyle(.glassProminent)
				.accessibilityIdentifier("beliefs.done")
		}
		.padding(.vertical, 6)
	}
}

private struct BeliefSummaryRow: View {
	let answer: BeliefSession.Answer

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(answer.question.statement)

			HStack(spacing: 6) {
				Text(answer.after.map(BeliefScale.words) ?? "No view")

				if answer.hasMoved {
					BeliefMoveArrow(from: answer.before, to: answer.after, hasHistory: true)
					Text("was \(answer.before.map(BeliefScale.words) ?? "no view")")
				}
			}
			.font(.caption)
			.foregroundStyle(.secondary)
		}
		.padding(.vertical, 2)
	}
}

/// Library entries as rows that open them
struct BeliefEntryLinks: View {
	let entries: [String]

	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		ForEach(entries, id: \.self) { reference in
			if let link = BeliefEntryLink(reference) {
				Button {
					navigation.openLibraryEntry(category: link.category, id: link.id)
				} label: {
					Label(link.name, systemImage: link.category.symbol)
						.foregroundStyle(link.category.themeColor)
				}
			}
		}
	}
}

/// A `category/id` the library has, with its name
private struct BeliefEntryLink {
	let category: LibraryContent
	let id: String
	let name: String

	init?(_ reference: String) {
		let parts = reference.split(separator: "/", maxSplits: 1).map(String.init)
		guard
			parts.count == 2,
			let category = LibraryContent(rawValue: parts[0]),
			let entry = LibraryCatalog.shared?.entry(category: parts[0], id: parts[1])
		else { return nil }
		self.category = category
		id = parts[1]
		name = entry.name
	}
}
