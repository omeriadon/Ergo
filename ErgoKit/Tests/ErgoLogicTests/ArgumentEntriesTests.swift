//
//  ArgumentEntriesTests.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import Foundation
import Testing

/// Links turned into `premise, premise ∴ conclusion` for the checker
struct ArgumentEntriesTests {
	let id = ArgumentFixtures.id
	let vocabulary = ArgumentFixtures.vocabulary

	func map(_ logic: [String], links: [(Int, Int)]) -> TestMap {
		TestMap(
			statements: logic.enumerated().map { ArgumentFixtures.statement($0.offset + 1, logic: $0.element) },
			links: links.map { ArgumentFixtures.link($0.0, $0.1) }
		)
	}

	@Test func modusPonens() throws {
		let map = map(["X→Y", "X", "Y"], links: [(1, 3), (2, 3)])
		let built = try #require(try ArgumentEntries.build(for: id(3), in: map))
		#expect(vocabulary.text(for: built.entries) == "X→Y,X∴Y")
		#expect(built.premises == [id(1), id(2)])
		#expect(built.conclusion == id(3))
		#expect(try ArgumentEntries.check(statement: id(3), in: map)?.verdict == .valid)
	}

	@Test func thereIsAnArgumentToParseBack() throws {
		let map = map(["X→Y", "X", "Y"], links: [(1, 3), (2, 3)])
		let built = try #require(try ArgumentEntries.build(for: id(3), in: map))
		let parse = LogicParser.parse(built.entries)
		#expect(parse.diagnostics.isEmpty)
		#expect(parse.argument.premises.count == 2)
		#expect(parse.marker == .symbol("∴"))
	}

	@Test func invalidArgumentsGetFallacies() throws {
		let map = map(["X→Y", "Y", "X"], links: [(1, 3), (2, 3)])
		let analysis = try #require(try ArgumentEntries.check(statement: id(3), in: map))
		#expect(analysis.fallacies.map(\.fallacyID) == ["affirming-the-consequent"])
		#expect(analysis.fallacies.first?.premises == [0, 1], "Indices line up with `premises`")
	}

	@Test func chainsAreTwoSmallArguments() throws {
		let map = map(["X", "X→Y", "Y→Z", "Y", "Z"], links: [(1, 4), (2, 4), (4, 5), (3, 5)])
		#expect(try ArgumentEntries.check(statement: id(4), in: map)?.verdict == .valid)
		#expect(try ArgumentEntries.check(statement: id(5), in: map)?.verdict == .valid)
		#expect(try ArgumentEntries.check(statement: id(1), in: map) == nil, "A root has no premises")
	}

	@Test func premisesFollowReadingOrderNotLinkOrder() throws {
		var map = map(["X", "Y", "X∧Y"], links: [(2, 3), (1, 3)])
		#expect(try ArgumentEntries.build(for: id(3), in: map)?.premises == [id(1), id(2)])
		map.statements[0].position = CanvasPoint(x: 900, y: 0)
		#expect(try ArgumentEntries.build(for: id(3), in: map)?.premises == [id(2), id(1)])
	}

	@Test func nothingToCheckIsNil() throws {
		#expect(try ArgumentEntries.check(statement: id(1), in: map(["X"], links: [])) == nil)

		let blankPremise = map(["", "Y"], links: [(1, 2)])
		#expect(try ArgumentEntries.check(statement: id(2), in: blankPremise) == nil)
		let blankConclusion = map(["X", ""], links: [(1, 2)])
		#expect(try ArgumentEntries.check(statement: id(2), in: blankConclusion) == nil)
		var newLines = map(["X", "Y"], links: [(1, 2)])
		newLines.statements[0].logic = [.delimiter("\n")]
		#expect(try ArgumentEntries.check(statement: id(2), in: newLines) == nil, "Only new lines is empty")
	}

	@Test func logicThatDoesNotParseIsATypedProblem() {
		let broken = map(["X∧", "Y"], links: [(1, 2)])
		#expect(throws: ArgumentEntriesProblem.self) { try ArgumentEntries.check(statement: id(2), in: broken) }

		do {
			_ = try ArgumentEntries.build(for: id(2), in: broken)
			Issue.record("Should have thrown")
		} catch {
			#expect(error.statement == id(1))
			guard case .doesNotParse = error else {
				Issue.record("Expected doesNotParse, got \(error)")
				return
			}
			#expect(error.message == "Expected a statement that parses, found a formula with mistakes")
		}
	}

	@Test func brokenOutranksEmpty() {
		let map = map(["", "X∧", "Y"], links: [(1, 3), (2, 3)])
		#expect(throws: ArgumentEntriesProblem.self) { try ArgumentEntries.build(for: id(3), in: map) }
	}

	@Test func boxesHoldOneStatement() {
		for text in ["X,Y", "X\nY", "X∴Y", "∴X", "X∎", "X,", "⊢"] {
			let map = map([text, "Y"], links: [(1, 2)])
			do {
				_ = try ArgumentEntries.build(for: id(2), in: map)
				Issue.record("\(text) should not be one statement")
			} catch {
				switch error {
					case .notOneStatement, .doesNotParse:
						break
					case .unknownStatement:
						Issue.record("Wrong problem for \(text): \(error)")
				}
			}
		}
	}

	@Test func strayNewLinesAroundAStatementAreFine() throws {
		var map = map(["X", "Y"], links: [(1, 2)])
		map.statements[0].logic = [.delimiter("\n")] + ArgumentFixtures.logic("X→Y") + [.delimiter("\n")]
		#expect(try ArgumentEntries.build(for: id(2), in: map).map { vocabulary.text(for: $0.entries) } == "X→Y∴Y")
	}

	@Test func bracketsKeepTheirCommas() throws {
		let map = map(["P(X,Y)", "∀XP(X,Y)"], links: [(1, 2)])
		#expect(try ArgumentEntries.build(for: id(2), in: map).map { vocabulary.text(for: $0.entries) } == "P(X,Y)∴∀XP(X,Y)")
		#expect(try ArgumentEntries.check(statement: id(2), in: map)?.verdict != nil)
	}

	@Test func unknownStatements() {
		let map = map(["X"], links: [])
		#expect(throws: ArgumentEntriesProblem.unknownStatement(id(9))) { try ArgumentEntries.build(for: id(9), in: map) }

		var dangling = map
		dangling.links = [ArgumentFixtures.link(7, 1)]
		#expect(throws: ArgumentEntriesProblem.unknownStatement(id(7))) { try ArgumentEntries.build(for: id(1), in: dangling) }
	}

	@Test func selfLinksAreNotPremises() throws {
		let map = map(["X"], links: [(1, 1)])
		#expect(try ArgumentEntries.build(for: id(1), in: map) == nil)
	}
}
