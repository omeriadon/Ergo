//
//  LogicCourseView.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

/// At the top of the Logic tab's list
struct LogicCourseRow: View {
	@Default(.logicCourseFinished) private var finished

	/// Off in the sidebar, where selecting a row doesn't push anything
	let showsChevron: Bool

	init(showsChevron: Bool = true) {
		self.showsChevron = showsChevron
	}

	var body: some View {
		HStack {
			Label {
				VStack(alignment: .leading, spacing: 2) {
					Text("Learn Logic")
						.font(.headline)
					Text("\(finished.count) of \(LogicCourse.lessons.count) lessons")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			} icon: {
				Image(systemName: "graduationcap")
			}

			Spacer(minLength: 0)

			if showsChevron {
				Image(systemName: "chevron.right")
					.foregroundStyle(.secondary)
			}
		}
		.contentShape(Rectangle())
	}
}

struct LogicCourseView: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(TranslationAccount.self)
	private var account

	@Default(.logicCourseFinished) private var finished

	var body: some View {
		List(LogicCourse.lessons) { lesson in
			let isOpen = LogicCourse.isFree(lesson) || account.hasPlusFeatures

			Button {
				if isOpen {
					navigation.logicPath.append(.lesson(lesson.id))
				} else {
					navigation.presentSheet(.plus)
				}
			} label: {
				LogicLessonRow(lesson: lesson, isFinished: finished.contains(lesson.id), isOpen: isOpen)
			}
			.buttonStyle(.plain)
			.accessibilityIdentifier("logic.lesson.\(lesson.id)")
		}
		.navigationTitle("Learn Logic")
		.navigationBarTitleDisplayMode(.inline)
	}
}

private struct LogicLessonRow: View {
	let lesson: LogicLesson
	let isFinished: Bool
	let isOpen: Bool

	private var symbol: String {
		isFinished ? "checkmark.circle.fill" : isOpen ? "circle" : "lock.fill"
	}

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: symbol)
				.foregroundStyle(isFinished ? .green : .secondary)
				.accessibilityLabel(isFinished ? "Finished" : isOpen ? "Not finished" : "Needs Ergo Plus")

			VStack(alignment: .leading, spacing: 2) {
				Text(lesson.title)
					.font(.headline)
				Text(lesson.summary)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)
		}
		.contentShape(Rectangle())
	}
}

/// A lesson's text, then its exercises. Getting them all right finishes it.
struct LogicLessonView: View {
	let lessonID: String

	@Environment(TranslationAccount.self)
	private var account

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.logicCourseFinished) private var finished

	/// The exercises got right so far
	@State private var correct: Set<LogicExercise.ID> = []

	var body: some View {
		if let lesson = LogicCourse.lesson(lessonID) {
			if LogicCourse.isFree(lesson) || account.hasPlusFeatures {
				content(lesson)
			} else {
				locked
			}
		}
	}

	/// Only reached by a route saved before the plan ended
	private var locked: some View {
		ContentUnavailableView {
			Label("This Lesson Needs Ergo Plus", systemImage: "lock.fill")
		} actions: {
			Button("See Ergo Plus") {
				navigation.presentSheet(.plus)
			}
			.buttonStyle(.glassProminent)
		}
	}

	private func content(_ lesson: LogicLesson) -> some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				ForEach(lesson.paragraphs, id: \.self) { paragraph in
					Text(paragraph)
				}

				Text("Is it valid?")
					.font(.title3.bold())
					.padding(.top, 8)

				ForEach(lesson.exercises) { exercise in
					LogicExerciseCard(exercise: exercise) {
						correct.insert(exercise.id)
						if correct.count == lesson.exercises.count {
							finished.insert(lesson.id)
						}
					}
				}

				if finished.contains(lesson.id) {
					Label("Lesson finished", systemImage: "checkmark.circle.fill")
						.foregroundStyle(.green)
						.accessibilityIdentifier("logic.lessonFinished")
				}
			}
			.padding()
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.navigationTitle(lesson.title)
		.navigationBarTitleDisplayMode(.inline)
	}
}

private struct LogicExerciseCard: View {
	let exercise: LogicExercise
	let answeredCorrectly: () -> Void

	/// Nil until answered. A wrong answer can be changed.
	@State private var answer: Bool?

	private var isCorrect: Bool {
		answer == exercise.isValid
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(exercise.argument)
				.font(.title3.monospaced())
				.minimumScaleFactor(0.6)
				.lineLimit(1)

			Text(exercise.reading)
				.font(.subheadline)
				.foregroundStyle(.secondary)

			HStack(spacing: 8) {
				choice("Valid", true)
				choice("Invalid", false)
			}

			if answer != nil {
				feedback
					.transition(.blurReplace)
			}
		}
		.padding(14)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
		.animation(.smooth, value: answer)
		.accessibilityIdentifier("logic.exercise")
	}

	private var feedback: some View {
		VStack(alignment: .leading, spacing: 4) {
			Label(isCorrect ? "Right" : "Not quite", systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(isCorrect ? .green : .orange)

			Text(isCorrect ? exercise.explanation : "Try imagining the premises true and the conclusion false.")
				.font(.subheadline)
		}
	}

	private func choice(_ title: String, _ value: Bool) -> some View {
		Button(title) {
			answer = value
			if value == exercise.isValid {
				answeredCorrectly()
			}
		}
		.buttonStyle(.glass)
		.disabled(answer == exercise.isValid)
	}
}
