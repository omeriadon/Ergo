//
//  TranslationScopeTests.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoTranslation
import Foundation
import Testing

/// Pages that already name some letters, and breaking down a pasted argument without formalizing it
struct TranslationScopeTests {
	let letters = LogicLetters.defaults
	let vocabulary = LogicInputVocabulary(letters: LogicLetters.defaults)

	let english = "If it rains, the ground gets wet. It rained, so the ground is wet."
	let gate = #"{"kind": "argument", "reason": ""}"#
	let statements = #"{"kind": "statements", "reason": ""}"#
	let breakdown = #"{"premises": ["If it rains, the ground gets wet", "It rained"], "conclusion": "the ground is wet", "claims": [{"meaning": "It rains", "descriptor": "it rains"}, {"meaning": "The ground is wet", "descriptor": "The Ground is wet"}]}"#
	let matches = #"{"matches": true, "differences": []}"#

	/// The ground is wet is already P, the fourth slot
	let named = ["", "", "", "the ground is wet", "", ""]

	func pipeline(_ backend: ScriptedBackend, descriptors: [String]?) -> TranslationPipeline {
		TranslationPipeline(backend: backend, letters: letters, descriptors: descriptors)
	}

	func decode<Input: Decodable>(_: Input.Type, _ json: String) throws -> Input {
		try JSONDecoder().decode(Input.self, from: Data(json.utf8))
	}

	// MARK: - Existing descriptors

	@Test func matchingClaimsKeepTheirLetter() async throws {
		let backend = ScriptedBackend([
			"gate": [gate], "breakdown": [breakdown], "verify": [matches],
			"formalize": [#"{"premises": ["X → P", "X"], "conclusion": "P"}"#],
		])
		let events = EventLog()
		let translated = try await pipeline(backend, descriptors: named).translate(english) { events.record($0) }

		// Matching ignores case. It rains takes the first free slot, the wet ground keeps P.
		let expected = ["it rains", "", "", "the ground is wet", "", ""]
		#expect(translated.entries == vocabulary.entries(in: "X→P\nX\n∴P"))
		#expect(translated.descriptors == expected)
		#expect(translated.issues.isEmpty)
		#expect(events.all.contains(.foundClaims(
			premises: ["If it rains, the ground gets wet", "It rained"],
			conclusion: "the ground is wet",
			descriptors: expected
		)))

		let formalize = try decode(FormalizeStage.Input.self, backend.lastInput("formalize"))
		#expect(formalize.letters.map(\.letter) == ["X", "P"])
		#expect(formalize.letters.map(\.meaning) == ["It rains", "The ground is wet"])
		#expect(formalize.descriptors?.map(\.letter) == ["P"])
		#expect(formalize.descriptors?.map(\.meaning) == ["the ground is wet"])

		let breakdownInput = try decode(BreakdownStage.Input.self, backend.lastInput("breakdown"))
		#expect(breakdownInput.descriptors == ["the ground is wet"])
	}

	@Test func existingLettersAreTakenForOtherClaims() async throws {
		// X and Y are named, neither by a claim here, so the new claims go to Z and P
		let backend = ScriptedBackend([
			"gate": [gate], "breakdown": [breakdown], "verify": [matches],
			"formalize": [#"{"premises": ["Z → P", "Z"], "conclusion": "P"}"#],
		])
		let translated = try await pipeline(backend, descriptors: ["kim passed", "lee passed", "", "", "", ""]).translate(english)

		#expect(translated.descriptors == ["kim passed", "lee passed", "it rains", "The Ground is wet", "", ""])
		let formalize = try decode(FormalizeStage.Input.self, backend.lastInput("formalize"))
		#expect(formalize.letters.map(\.letter) == ["Z", "P"])
		#expect(formalize.descriptors?.map(\.letter) == ["X", "Y"])
	}

	@Test func aLetterTheStatementWasntGivenIsACompilerError() async throws {
		let backend = ScriptedBackend([
			"gate": [gate], "breakdown": [breakdown], "verify": [matches],
			"formalize": [#"{"premises": ["X → Y", "X"], "conclusion": "Y"}"#, #"{"premises": ["X → P", "X"], "conclusion": "P"}"#],
		])
		let events = EventLog()
		_ = try await pipeline(backend, descriptors: named).translate(english) { events.record($0) }

		#expect(backend.count("formalize") == 2)
		#expect(events.all.contains(.retrying(problems: [
			"Premise 1 'X → Y': Expected only the letters X, P, found 'Y'",
			"Conclusion 'Y': Expected only the letters X, P, found 'Y'",
		], attempt: 1)))
	}

	@Test func tooManyNewClaimsForTheFreeLetters() async throws {
		let backend = ScriptedBackend(["gate": [gate], "breakdown": [breakdown]])
		let crowded = ["a", "b", "c", "d", "e", ""]
		let translated = try await pipeline(backend, descriptors: crowded).translate(english)

		#expect(translated.entries.isEmpty)
		#expect(translated.issues == [TranslationIssue(
			severity: .error,
			message: "Expected at most 1 new claim, found 2, the page's other letters are taken"
		)])
		#expect(backend.count("formalize") == 0)
	}

	@Test func noDescriptorsLeavesTheInputsAsTheyWere() async throws {
		let backend = ScriptedBackend([
			"gate": [gate], "breakdown": [breakdown], "verify": [matches],
			"formalize": [#"{"premises": ["X → Y", "X"], "conclusion": "Y"}"#],
		])
		let translated = try await pipeline(backend, descriptors: nil).translate(english)

		#expect(translated.descriptors == ["it rains", "The Ground is wet", "", "", "", ""])
		#expect(!backend.lastInput("breakdown").contains("descriptors"))
		#expect(!backend.lastInput("formalize").contains("\"descriptors\""))
	}

	// MARK: - Breaking down

	@Test func breakingDownStopsAfterTheBreakdown() async throws {
		let backend = ScriptedBackend(["gate": [gate], "breakdown": [breakdown]])
		let events = EventLog()
		let result = try await pipeline(backend, descriptors: named).breakDown(english) { events.record($0) }

		#expect(backend.requests.map(\.stage) == ["gate", "breakdown"])
		#expect(result.kind == .argument)
		#expect(result.premises == ["If it rains, the ground gets wet", "It rained"])
		#expect(result.conclusion == "the ground is wet")
		#expect(result.claims.map(\.meaning) == ["It rains", "The ground is wet"])
		#expect(result.descriptors == ["it rains", "", "", "the ground is wet", "", ""])
		#expect(result.issues.isEmpty)
		#expect(events.all == [
			.started(step: .gate, attempt: 1),
			.started(step: .breakdown, attempt: 1),
			.foundClaims(
				premises: ["If it rains, the ground gets wet", "It rained"],
				conclusion: "the ground is wet",
				descriptors: ["it rains", "", "", "the ground is wet", "", ""]
			),
		])
	}

	@Test func breakingDownClaimsWithoutAConclusion() async throws {
		let backend = ScriptedBackend(["gate": [statements], "breakdown": [breakdown]])
		let result = try await pipeline(backend, descriptors: nil).breakDown(english)

		#expect(result.kind == .statements)
		#expect(result.conclusion.isEmpty)
		#expect(result.premises.count == 2)
		#expect(result.descriptors == ["it rains", "The Ground is wet", "", "", "", ""])
	}

	@Test func breakingDownWhatIsntLogicKeepsTheDescriptors() async throws {
		let backend = ScriptedBackend(["gate": [#"{"kind": "neither", "reason": "Expected claims, found a question"}"#]])
		let result = try await pipeline(backend, descriptors: named).breakDown("Is it going to rain today or not?")

		#expect(result.kind == .neither)
		#expect(result.premises.isEmpty)
		#expect(result.claims.isEmpty)
		#expect(result.descriptors == named)
		#expect(result.issues == [TranslationIssue(severity: .error, message: "Expected claims, found a question")])
		#expect(backend.requests.map(\.stage) == ["gate"])
	}

	@Test func breakingDownGibberishNeverReachesTheBackend() async throws {
		let quiet = ScriptedBackend([:])
		let events = EventLog()
		let result = try await pipeline(quiet, descriptors: nil).breakDown("→∧¬ ∨∨ ()") { events.record($0) }

		#expect(result.issues.first?.severity == .error)
		#expect(quiet.requests.isEmpty)
		#expect(events.all.isEmpty)
	}

	@Test func breakingDownTooManyNewClaimsFails() async throws {
		let backend = ScriptedBackend(["gate": [gate], "breakdown": [breakdown]])
		let result = try await pipeline(backend, descriptors: ["a", "b", "c", "d", "e", ""]).breakDown(english)

		#expect(result.premises.isEmpty)
		#expect(result.descriptors == ["a", "b", "c", "d", "e", ""])
		#expect(result.issues.first?.message == "Expected at most 1 new claim, found 2, the page's other letters are taken")
	}

	@Test func breakingDownCancels() async throws {
		let backend = ScriptedBackend(["gate": [gate], "breakdown": [breakdown]])
		let task = Task {
			withUnsafeCurrentTask { $0?.cancel() }
			return try await pipeline(backend, descriptors: nil).breakDown(english)
		}
		await #expect(throws: CancellationError.self) {
			try await task.value
		}
		#expect(backend.requests.isEmpty)
	}
}
