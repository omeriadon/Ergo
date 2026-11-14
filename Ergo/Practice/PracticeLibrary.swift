//
//  PracticeLibrary.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import ErgoCatalog
import ErgoLogic
import Foundation

/// The cards practice asks: the library's, built once off the main actor, and the course's, from the lessons this
/// person has finished and can still open
enum PracticeLibrary {
	private static var library: PracticeDeck?

	static func deck(courseLessons lessons: [LogicLesson]) async throws -> PracticeDeck {
		let library: PracticeDeck
		if let cached = Self.library {
			library = cached
		} else {
			library = try await load()
			Self.library = library
		}
		return library.adding(courseCards(lessons))
	}

	@concurrent
	private nonisolated static func load() async throws -> PracticeDeck {
		try PracticeDeck.loadLibrary()
	}

	/// The lessons whose exercises practice reviews: finished, and open to this person
	static func courseLessons(finished: Set<String>, hasPlus: Bool) -> [LogicLesson] {
		LogicCourse.lessons.filter { finished.contains($0.id) && (hasPlus || LogicCourse.isFree($0)) }
	}

	nonisolated static func courseCards(_ lessons: [LogicLesson]) -> [PracticeCard] {
		lessons.flatMap { lesson in
			lesson.exercises.map { exercise in
				PracticeCard.exercise(
					lessonID: lesson.id,
					lessonTitle: lesson.title,
					argument: exercise.argument,
					reading: exercise.reading,
					isValid: exercise.isValid,
					explanation: exercise.explanation
				)
			}
		}
	}

	// MARK: - Wording

	/// Topics in the order they're listed: the course first, then the library grid's order
	static let topics = [PracticeCard.courseTopic] + PracticeDeck.categories

	static func title(of topic: String) -> String {
		topic == PracticeCard.courseTopic ? "Logic Course" : LibraryContent(rawValue: topic)?.title ?? topic.capitalized
	}

	static func symbol(of topic: String) -> String {
		topic == PracticeCard.courseTopic ? "graduationcap" : LibraryContent(rawValue: topic)?.symbol ?? "questionmark"
	}

	/// What the card asks, above its prompt
	static func question(for card: PracticeCard) -> String {
		switch card.kind {
			case .identify:
				card.topic == "philosophers" ? "Who is this?" : "Which \(singular(card.topic)) is this?"
			case .define:
				card.topic == "philosophers" ? "Which describes them?" : "What does it mean?"
			case .validity:
				"Is it valid?"
		}
	}

	private static func singular(_ topic: String) -> String {
		switch topic {
			case "biases":
				"bias"
			case "fallacies":
				"fallacy"
			case "paradoxes":
				"paradox"
			case "concepts", "symbols", "razors", "arguments":
				String(topic.dropLast())
			default:
				"entry"
		}
	}
}
