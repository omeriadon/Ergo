//
//  ArgumentTextTests.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import Foundation
import Testing

/// A map as a block of text and back, keeping identity for lines that didn't change
struct ArgumentTextTests {
	let id = ArgumentFixtures.id
	let vocabulary = ArgumentFixtures.vocabulary

	/// X→Y, X ∴ Y, in the English a translator would give
	func modusPonens() -> TestMap {
		TestMap(
			statements: [
				ArgumentFixtures.statement(1, logic: "X→Y", english: "If it rains, the ground is wet."),
				ArgumentFixtures.statement(2, logic: "X", english: "It rains."),
				ArgumentFixtures.statement(3, logic: "Y", english: "The ground is wet."),
			],
			links: [ArgumentFixtures.link(1, 3), ArgumentFixtures.link(2, 3)]
		)
	}

	func apply(_ text: String, _ kind: ArgumentTextKind, to map: TestMap, ids: ArgumentFixtures.Generator = .init()) throws -> ArgumentTextChange<ArgumentStatement, ArgumentLinkValue> {
		try ArgumentText.apply(text: text, kind: kind, to: map, makeID: { ids() })
	}

	// MARK: - Writing

	@Test func writesEnglish() {
		#expect(ArgumentText.text(of: modusPonens(), kind: .english) == "If it rains, the ground is wet.\nIt rains.\nTherefore, The ground is wet.")
	}

	@Test func writesLogic() {
		#expect(ArgumentText.text(of: modusPonens(), kind: .logic) == "X→Y\nX\n∴Y")
		#expect(ArgumentText.text(of: modusPonens(), kind: .logic, letters: ["A", "B", "C", "D", "E", "F"]) == "A→B\nA\n∴B")
		#expect(vocabulary.text(for: ArgumentText.entries(for: modusPonens())) == "X→Y\nX\n∴Y")
	}

	@Test func emptyMapIsEmptyText() {
		#expect(ArgumentText.text(of: TestMap(), kind: .english).isEmpty)
		#expect(ArgumentText.text(of: TestMap(), kind: .logic).isEmpty)
	}

	@Test func unlinkedStatementsHaveNoConclusionLine() {
		let map = TestMap(statements: [ArgumentFixtures.statement(1, logic: "X"), ArgumentFixtures.statement(2, logic: "Y")])
		#expect(ArgumentText.text(of: map, kind: .logic) == "X\nY")
		#expect(ArgumentText.order(of: map, kind: .logic).conclusion == nil)
	}

	@Test func orderIsTopologicalWithTiesByPosition() {
		var map = modusPonens()
		map.statements[0].position = CanvasPoint(x: 0, y: 300)
		map.statements[1].position = CanvasPoint(x: 0, y: 100)
		#expect(ArgumentText.order(of: map, kind: .logic).statements == [id(2), id(1), id(3)])
		#expect(ArgumentText.order(of: map, kind: .logic).conclusion == id(3))
	}

	@Test func theConclusionComesLastEvenWhenItIsHigherUp() {
		var map = modusPonens()
		map.statements[2].position = CanvasPoint(x: -500, y: -500)
		let order = ArgumentText.order(of: map, kind: .logic)
		#expect(order.statements.last == id(3))
		#expect(order.conclusion == id(3))
	}

	@Test func chainsAreWrittenInOrder() {
		let map = TestMap(
			statements: [
				ArgumentFixtures.statement(1, logic: "X"),
				ArgumentFixtures.statement(2, logic: "X→Y"),
				ArgumentFixtures.statement(3, logic: "Y"),
				ArgumentFixtures.statement(4, logic: "Y→Z"),
				ArgumentFixtures.statement(5, logic: "Z"),
			],
			links: [ArgumentFixtures.link(1, 3), ArgumentFixtures.link(2, 3), ArgumentFixtures.link(3, 5), ArgumentFixtures.link(4, 5)]
		)
		#expect(ArgumentText.text(of: map, kind: .logic) == "X\nX→Y\nY\nY→Z\n∴Z")
	}

	@Test func statementsWithNoContentAreLeftOut() {
		var map = modusPonens()
		map.statements[1].english = ""
		#expect(ArgumentText.text(of: map, kind: .english) == "If it rains, the ground is wet.\nTherefore, The ground is wet.")
		map.statements[2].logic = []
		#expect(ArgumentText.text(of: map, kind: .logic) == "X→Y\nX")
	}

	@Test func englishCommasStayInsideTheirLine() {
		let map = TestMap(statements: [
			ArgumentFixtures.statement(1, english: "If it rains, then, unless we cover it, the ground is wet."),
			ArgumentFixtures.statement(2, english: "Apples, pears, and plums"),
		])
		#expect(ArgumentText.text(of: map, kind: .english).split(separator: "\n").count == 2)
	}

	// MARK: - Reading English

	@Test func englishConclusionMarkers() throws {
		for marker in ["Therefore,", "therefore", "Hence,", "hence", "Thus,", "THUS", "∴", "∴ ", "Therefore ,"] {
			let change = try apply("It rains.\n\(marker) the ground is wet.", .english, to: TestMap())
			#expect(change.map.statements.map(\.english) == ["It rains.", "the ground is wet."], "Marker \(marker)")
			#expect(change.map.links.count == 1, "Marker \(marker)")
		}
	}

	@Test func wordsThatOnlyStartLikeMarkersAreStatements() throws {
		let change = try apply("Thusly it goes.\nHenceforth we leave.", .english, to: TestMap())
		#expect(change.map.statements.count == 2)
		#expect(change.map.links.isEmpty)
	}

	@Test func englishProblems() {
		#expect(throws: ArgumentTextProblem.missingConclusion) { try apply("It rains.\nTherefore,", .english, to: TestMap()) }
		#expect(throws: ArgumentTextProblem.multipleConclusions) { try apply("A.\nTherefore, B.\nThus, C.", .english, to: TestMap()) }
		#expect(ArgumentTextProblem.multipleConclusions.message == "Expected one conclusion, found several")
	}

	@Test func blankLinesAreIgnored() throws {
		let change = try apply("\n\n  It rains.  \n\n\nTherefore, wet.\n\n", .english, to: TestMap())
		#expect(change.map.statements.map(\.english) == ["It rains.", "wet."])
	}

	// MARK: - Reading logic

	@Test func logicUsesTheParsersSeparators() throws {
		for text in ["X→Y,X∴Y", "X→Y\nX\n∴Y", "X→Y,X\n∴Y", "X→Y\nX⊢Y", "X→Y, X ⊨ Y", "X→Y,X∴Y\n∎"] {
			let change = try apply(text, .logic, to: TestMap())
			#expect(change.map.statements.map { vocabulary.text(for: $0.logic) } == ["X→Y", "X", "Y"], "Text \(text)")
			#expect(change.map.links.count == 2, "Text \(text)")
		}
	}

	@Test func splittingMatchesTheParser() throws {
		for text in ["X→Y,X∴Y", "P(X,Y),Q∴R", "P(X,Y),[X→Y]\nZ∴Y", "X\nY\nZ"] {
			let entries = vocabulary.entries(in: text)
			let parse = LogicParser.parse(entries)
			let change = try ArgumentText.apply(entries: entries, to: TestMap())

			let expected = parse.argument.premises.map { vocabulary.text(for: Array(entries[$0.range])) }
				+ (parse.argument.conclusion.map { [vocabulary.text(for: Array(entries[$0.range]))] } ?? [])
			#expect(change.map.statements.map { vocabulary.text(for: $0.logic) } == expected, "Text \(text)")
		}
	}

	@Test func logicCommasInsideBracketsStayInTheStatement() throws {
		let change = try apply("P(X,Y),Q∴∀XP(X,Y)", .logic, to: TestMap())
		#expect(change.map.statements.map { vocabulary.text(for: $0.logic) } == ["P(X,Y)", "Q", "∀XP(X,Y)"])
	}

	@Test func logicThatDoesNotParseIsStillAStatement() throws {
		let change = try apply("X∧\nY∴X", .logic, to: TestMap())
		#expect(change.map.statements.map { vocabulary.text(for: $0.logic) } == ["X∧", "Y", "X"])
	}

	@Test func logicProblems() {
		#expect(throws: ArgumentTextProblem.missingConclusion) { try apply("X∴", .logic, to: TestMap()) }
		#expect(throws: ArgumentTextProblem.multipleConclusions) { try apply("X∴Y,Z", .logic, to: TestMap()) }
		#expect(throws: ArgumentTextProblem.multipleConclusions) { try apply("X∴Y∴Z", .logic, to: TestMap()) }
		#expect(throws: ArgumentTextProblem.unsupportedMarker("∵")) { try apply("Y∵X", .logic, to: TestMap()) }
		#expect(ArgumentTextProblem.unsupportedMarker("∵").message == "Expected '∴' before the conclusion, found '∵'")
	}

	@Test func logicTextUsesTheCurrentLetters() throws {
		let change = try ArgumentText.apply(text: "A→B,A∴B", kind: .logic, letters: ["A", "B", "C", "D", "E", "F"], to: TestMap())
		#expect(change.map.statements.map(\.logic) == [
			[.variable(1), .symbol("→"), .variable(2)], [.variable(1)], [.variable(2)],
		])
	}

	// MARK: - Identity

	@Test func roundTripLeavesTheMapUnchanged() throws {
		var maps = [TestMap(), ArgumentFixtures.map(1), modusPonens()]
		var diamond = TestMap(
			statements: (1 ... 4).map { ArgumentFixtures.statement($0, logic: ["X", "Y", "Z", "P"][$0 - 1], english: "Claim \($0).", x: Double($0 / 2) * 300, y: Double($0 % 2) * 120) },
			links: [(1, 2), (1, 3), (2, 4), (3, 4)].map { ArgumentFixtures.link($0.0, $0.1) }
		)
		maps.append(diamond)
		diamond.links.removeAll()
		maps.append(diamond)

		for map in maps {
			for kind in [ArgumentTextKind.english, .logic] {
				let text = ArgumentText.text(of: map, kind: kind)
				let change = try apply(text, kind, to: map)
				#expect(change.map == map, "\(kind) text:\n\(text)")
				#expect(change.edited.isEmpty && change.added.isEmpty && change.removed.isEmpty)
			}
		}
	}

	@Test func roundTripOfAnEnglishConclusionKeepsItsCase() throws {
		var map = modusPonens()
		map.statements[2].english = "iPhone sales fell."
		let change = try apply(ArgumentText.text(of: map, kind: .english), .english, to: map)
		#expect(change.map == map)
	}

	@Test func roundTripCollapsesNothingThatMatters() throws {
		var map = modusPonens()
		map.statements[0].english = "  If it rains,\n   the ground is wet.  "
		let change = try apply(ArgumentText.text(of: map, kind: .english), .english, to: map)
		#expect(change.map == map, "Whitespace differences are not edits")
	}

	@Test func roundTripOfAChainKeepsItsLinks() throws {
		let map = TestMap(
			statements: [1, 2, 3].map { ArgumentFixtures.statement($0, logic: ["X", "Y", "Z"][$0 - 1]) },
			links: [ArgumentFixtures.link(1, 2), ArgumentFixtures.link(2, 3)]
		)
		let change = try apply(ArgumentText.text(of: map, kind: .logic), .logic, to: map)
		#expect(change.map == map, "The text flattens a chain, but unchanged lines keep the links they had")
	}

	@Test func editedLinesUpdateInPlace() throws {
		let map = modusPonens()
		let change = try apply("If it rains, the ground gets wet.\nIt rains.\nTherefore, The ground is wet.", .english, to: map)

		#expect(change.edited == [id(1)])
		#expect(change.added.isEmpty && change.removed.isEmpty)
		#expect(change.map.statements[0].english == "If it rains, the ground gets wet.")
		#expect(change.map.statements[0].position == map.statements[0].position)
		#expect(change.map.statements[0].logic == map.statements[0].logic, "The other field is left for the app to mark stale")
		#expect(change.map.links == map.links)
	}

	@Test func theConclusionIsEditedInPlaceToo() throws {
		let change = try apply("X→Y\nX\n∴Z", .logic, to: modusPonens())
		#expect(change.edited == [id(3)])
		#expect(change.map.links.count == 2)
		#expect(change.map.statements[2].id == id(3))
	}

	@Test func removedLinesDeleteTheirStatementAndLinks() throws {
		let change = try apply("X→Y\n∴Y", .logic, to: modusPonens())
		#expect(change.removed == [id(2)])
		#expect(change.map.statements.map(\.id) == [id(1), id(3)])
		#expect(change.map.links == [ArgumentFixtures.link(1, 3)])
	}

	@Test func deletingALineInTheMiddleDoesNotShiftTheRest() throws {
		let map = TestMap(statements: [1, 2, 3, 4].map { ArgumentFixtures.statement($0, logic: ["X", "Y", "Z", "P"][$0 - 1]) })
		let change = try apply("X\nZ\nP", .logic, to: map)
		#expect(change.removed == [id(2)])
		#expect(change.edited.isEmpty, "Z and P keep their statements instead of being rewritten in place")
		#expect(change.map.statements.map(\.id) == [id(1), id(3), id(4)])
	}

	@Test func deletingAPremiseAndEditingTheConclusionTogether() throws {
		let change = try apply("X→Y\n∴Q", .logic, to: modusPonens())
		#expect(change.removed == [id(2)])
		#expect(change.edited == [id(3)])
		#expect(change.map.links == [ArgumentFixtures.link(1, 3)])
	}

	@Test func newLinesBecomePremisesOfTheConclusion() throws {
		let ids = ArgumentFixtures.Generator()
		let map = modusPonens()
		let change = try apply("X→Y\nX\nZ\n∴Y", .logic, to: map, ids: ids)

		#expect(change.added == [id(5001)])
		let added = try #require(change.map.statements.first { $0.id == id(5001) })
		#expect(vocabulary.text(for: added.logic) == "Z")
		#expect(added.english.isEmpty)
		#expect(change.map.links.contains { $0.premise == id(5001) && $0.conclusion == id(3) })
		#expect(change.map.links.count == 3)
		#expect(ArgumentMapValidator.validate(change.map).isEmpty)
		#expect(map.statements.allSatisfy { old in change.map.statements.contains { $0.position == old.position && $0.id == old.id } })
	}

	@Test func newStatementsDoNotOverlapAnything() throws {
		var map = modusPonens()
		map = CanvasLayout.arranged(map)
		let change = try apply("X→Y\nX\nA\nB\nC\nD\n∴Y", .logic, to: map)

		let rects = change.map.statements.map { CanvasRect(center: $0.position, size: CanvasLayout.boxSize) }
		for (index, rect) in rects.enumerated() {
			for other in rects[(index + 1)...] {
				#expect(!rect.intersects(other))
			}
		}
	}

	@Test func aNewConclusionLineLinksTheLinesAboveIt() throws {
		let map = TestMap(statements: [ArgumentFixtures.statement(1, logic: "X"), ArgumentFixtures.statement(2, logic: "Y")])
		let ids = ArgumentFixtures.Generator()
		let change = try apply("X\nY\n∴Z", .logic, to: map, ids: ids)

		#expect(change.added == [id(5001)])
		#expect(change.map.links.map { [$0.premise, $0.conclusion] } == [[id(1), id(5001)], [id(2), id(5001)]])
		let target = try #require(change.map.statement(id(5001)))
		#expect(target.position.y > change.map.statements[0].position.y, "Placed below what feeds it")
	}

	@Test func promotingAnOldLineToConclusionLinksTheRest() throws {
		let map = TestMap(statements: [ArgumentFixtures.statement(1, logic: "X"), ArgumentFixtures.statement(2, logic: "Y")])
		let change = try apply("X\n∴Y", .logic, to: map)
		#expect(change.added.isEmpty)
		#expect(change.map.links.map { [$0.premise, $0.conclusion] } == [[id(1), id(2)]])
	}

	@Test func nothingIsLinkedWithoutAConclusionLine() throws {
		let change = try apply("X→Y\nX\nY\nZ", .logic, to: modusPonens())
		#expect(change.added.count == 1)
		#expect(change.map.links == modusPonens().links)
	}

	@Test func cyclesAreNeverCreated() throws {
		// 1 → 2 → 3 and the conclusion line is rewritten so that 3's old premise ends up above it
		let map = TestMap(
			statements: [ArgumentFixtures.statement(1, logic: "X"), ArgumentFixtures.statement(2, logic: "Y"), ArgumentFixtures.statement(3, logic: "Z")],
			links: [ArgumentFixtures.link(1, 2), ArgumentFixtures.link(2, 3)]
		)
		let change = try apply("Y\nZ\nX", .logic, to: map)
		#expect(ArgumentMapValidator.validate(change.map).isEmpty)
	}

	@Test func aFirstArgumentOnAnEmptyMapIsLaidOut() throws {
		let change = try apply("X→Y\nX\n∴Y", .logic, to: TestMap(), ids: .init())
		#expect(change.added.count == 3)
		#expect(change.map.statements.map(\.position).count == Set(change.map.statements.map(\.position)).count)
		#expect(ArgumentMapValidator.validate(change.map).isEmpty)

		let conclusion = try #require(change.map.statements.last)
		for premise in change.map.statements.dropLast() {
			#expect(premise.position.y < conclusion.position.y)
		}
	}

	@Test func unfinishedBoxesAreUntouched() throws {
		var map = modusPonens()
		map.statements.append(ArgumentFixtures.statement(4, x: 9000))
		map.links.append(ArgumentFixtures.link(4, 3))
		let change = try apply(ArgumentText.text(of: map, kind: .logic), .logic, to: map)
		#expect(change.map == map)

		let removedAll = try apply("", .logic, to: map)
		#expect(removedAll.map.statements.map(\.id) == [id(4)], "The blank box stays, and its link is gone with the conclusion")
		#expect(removedAll.map.links.isEmpty)
	}

	@Test func theStatementLimitIsEnforced() throws {
		let text = (1 ... 61).map { _ in "X" }.joined(separator: "\n")
		#expect(throws: ArgumentTextProblem.tooManyStatements(limit: 60, found: 61)) { try apply(text, .logic, to: TestMap()) }
		let ok = (1 ... 60).map { _ in "X" }.joined(separator: "\n")
		#expect(try apply(ok, .logic, to: TestMap(), ids: .init()).map.statements.count == 60)
		#expect(ArgumentTextProblem.tooManyStatements(limit: 60, found: 61).message == "Expected at most 60 statements, found 61")
	}

	@Test func sixtyStatementsRoundTrip() throws {
		let map = CanvasLayout.arranged(TestMap(
			statements: (1 ... 59).map { ArgumentFixtures.statement($0, logic: "X", english: "Claim \($0).") } + [ArgumentFixtures.statement(60, logic: "Y", english: "Done.")],
			links: (1 ... 59).map { ArgumentFixtures.link($0, 60) }
		))
		for kind in [ArgumentTextKind.english, .logic] {
			let change = try apply(ArgumentText.text(of: map, kind: kind), kind, to: map)
			#expect(change.map == map)
		}
	}
}
