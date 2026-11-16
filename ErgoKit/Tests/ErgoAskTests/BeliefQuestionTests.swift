//
//  BeliefQuestionTests.swift
//  ErgoKit
//
//  Created by Adon Omeri on 16/11/2026.
//

@testable import ErgoCatalog
import Foundation
import Testing

struct BeliefQuestionTests {
	private var sets: [BeliefQuestionSet] {
		BeliefQuestionBank.sets
	}

	// MARK: - The bank

	@Test func theBankLoads() {
		#expect(sets.count >= 2)
		#expect(sets.allSatisfy { !$0.questions.isEmpty })
	}

	@Test func idsAreUniqueAndQuestionsStartWithTheirSet() {
		let setIDs = sets.map(\.id)
		#expect(Set(setIDs).count == setIDs.count)

		let questionIDs = sets.flatMap { $0.questions.map(\.id) }
		#expect(Set(questionIDs).count == questionIDs.count)
		#expect(Set(questionIDs).isDisjoint(with: setIDs))

		for set in sets {
			for question in set.questions {
				#expect(question.id.hasPrefix(set.id + "-"), "\(question.id) isn't in \(set.id)'s namespace")
			}
		}
	}

	@Test func everySetHasItsOwnColour() {
		for set in sets {
			#expect(HexColor(set.color) != nil, "\(set.id) has colour \(set.color)")
		}
		let colours = sets.map { $0.color.uppercased() }
		#expect(Set(colours).count == colours.count)
	}

	@Test func everyStatementIsAClaim() {
		for set in sets {
			#expect(!set.title.isEmpty && !set.summary.isEmpty, "\(set.id)")
			for question in set.questions {
				let statement = question.statement.trimmingCharacters(in: .whitespacesAndNewlines)
				#expect(!statement.isEmpty, "\(question.id)")
				#expect(!statement.hasSuffix("?"), "\(question.id) is a question, not a claim")
			}
		}
	}

	@Test func everyEntryIsInTheLibrary() {
		for question in sets.flatMap(\.questions) {
			#expect(question.entries.count <= 3, "\(question.id)")
			for entry in question.entries {
				#expect(LibraryCatalog.entryIDs.contains(entry), "\(question.id) links to \(entry), which the library doesn't have")
			}
		}
	}

	// MARK: - Reading

	@Test func anUnreadableQuestionOrSetIsSkipped() throws {
		let json = """
		{"sets": [
			{"id": "a", "title": "A", "summary": "S", "color": "#112233", "questions": [
				{"id": "a-one", "statement": "One."},
				{"id": "a-two"}
			]},
			{"id": "b", "title": "B"}
		]}
		"""
		let sets = try BeliefQuestionBank.sets(in: Data(json.utf8))
		#expect(sets.map(\.id) == ["a"])
		#expect(sets.first?.questions.map(\.id) == ["a-one"])
		#expect(sets.first?.questions.first?.entries == [])
	}

	@Test func hexColoursOnlyReadSixDigits() {
		#expect(HexColor("#FF8000") == HexColor("#ff8000"))
		#expect(HexColor("#FF8000")?.green == 128.0 / 255)
		for text in ["FF8000", "#FF800", "#FF80000", "#GG8000", "#+F8000", ""] {
			#expect(HexColor(text) == nil, "\(text)")
		}
	}

	// MARK: - The scale

	@Test func theScaleSnapsToStepsAndHasWords() {
		#expect(BeliefScale.snapped(44) == 40)
		#expect(BeliefScale.snapped(46) == 50)
		#expect(BeliefScale.snapped(-5) == 0)
		#expect(BeliefScale.snapped(140) == 100)
		#expect(BeliefScale.words(for: 0) == "Very unlikely")
		#expect(BeliefScale.words(for: 30) == "Unlikely")
		#expect(BeliefScale.words(for: 50) == "Unsure")
		#expect(BeliefScale.words(for: 70) == "Likely")
		#expect(BeliefScale.words(for: 100) == "Very likely")
	}
}
