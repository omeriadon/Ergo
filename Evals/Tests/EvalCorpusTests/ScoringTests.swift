//
//  ScoringTests.swift
//  Evals
//
//  Created by Adon Omeri on 5/11/2026.
//

@testable import ErgoEval
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Testing

/// Scoring on made-up server replies, so a wrong outcome is the scorer's fault and not the model's
struct ScoringTests {
	let modusPonens = EvalCase(
		id: "modus-ponens",
		english: "If it rains, the ground gets wet. It's raining, so the ground is wet.",
		kind: .argument,
		expected: .init(premises: ["X→Y", "X"], conclusion: "Y"),
		verdict: .valid,
		tags: ["conditional"],
		note: nil
	)

	let question = EvalCase(
		id: "question",
		english: "Is it going to rain tomorrow?",
		kind: .neither,
		expected: nil,
		verdict: nil,
		tags: ["question"],
		note: nil
	)

	func run(_ messages: [TranslateServerMessage], thrown: ServiceError? = nil) -> EvalRun {
		EvalRun(caseID: "test", repetition: 1, messages: messages, seconds: 1, thrown: thrown)
	}

	func finished(_ logic: String, english: String = "", issues: [TranslationIssue] = []) -> [TranslateServerMessage] {
		let entries = LogicInputVocabulary(letters: Corpus.letters).entries(in: logic)
		return [
			.event(.started(step: .gate, attempt: 1)),
			.event(.started(step: .breakdown, attempt: 1)),
			.event(.started(step: .formalize, attempt: 1)),
			.finished(Translation(english: english, entries: entries, issues: issues)),
		]
	}

	@Test func renamedLettersAndReorderedPremisesPass() {
		#expect(Scoring.score(run(finished("Q\nQ→R\n∴R")), for: modusPonens).outcome == .pass)
	}

	@Test func theConverseIsTheWrongMeaning() {
		let score = Scoring.score(run(finished("X→Y\nY\n∴X")), for: modusPonens)
		#expect(score.outcome == .wrongMeaning)
		#expect(score.expected == "X → Y, X ∴ Y")
		#expect(score.got == "X → Y, Y ∴ X")
		#expect(score.gotReading != nil)
	}

	@Test func joiningPremisesStillPasses() {
		#expect(Scoring.score(run(finished("(X→Y)∧X\n∴Y")), for: modusPonens).outcome == .pass)
	}

	@Test func missingTheConclusionIsTheWrongKind() {
		#expect(Scoring.score(run(finished("X→Y\nX\nY")), for: modusPonens).outcome == .wrongKind)
	}

	@Test func modalLogicIsUnscorable() {
		#expect(Scoring.score(run(finished("□X→Y\nX\n∴Y")), for: modusPonens).outcome == .unscorable)
	}

	@Test func gateTurningAnArgumentAwayIsTheWrongKind() {
		let messages: [TranslateServerMessage] = [
			.event(.started(step: .gate, attempt: 1)),
			.finished(Translation(english: "", issues: [TranslationIssue(severity: .error, message: "Expected a claim")])),
		]
		#expect(Scoring.score(run(messages), for: modusPonens).outcome == .wrongKind)
		#expect(Scoring.score(run(messages), for: question).outcome == .pass)
	}

	@Test func givingUpAfterBreakdownFails() {
		let messages = finished("").dropLast() + [
			.finished(Translation(english: "", issues: [TranslationIssue(severity: .error, message: "Couldn't write this as valid logic")])),
		]
		#expect(Scoring.score(run(Array(messages)), for: modusPonens).outcome == .failed)
	}

	@Test func translatingAQuestionIsTheWrongKind() {
		#expect(Scoring.score(run(finished("X")), for: question).outcome == .wrongKind)
	}

	@Test func serviceErrorsFail() {
		let notConnected = ServiceError(code: .notConnected, message: "Claude isn't connected")
		let failed = Scoring.score(run([.failed(notConnected)]), for: question)
		#expect(failed.outcome == .failed)
		#expect(failed.problem == "notConnected: Claude isn't connected")

		let thrown = run([], thrown: ServiceError(code: .providerUnavailable, message: "Couldn't reach the Ergo server"))
		#expect(Scoring.score(thrown, for: modusPonens).outcome == .failed)
	}

	/// Every case's own answer, sent back as if the server wrote it, so the scorer copes with every shape in the corpus
	@Test(arguments: EvalCorpusTests.cases) func theAnswerKeyPasses(_ evalCase: EvalCase) {
		let messages: [TranslateServerMessage]
		if let expected = evalCase.expected {
			let conclusion = expected.conclusion.isEmpty ? "" : "\n∴" + expected.conclusion
			messages = finished(expected.premises.joined(separator: "\n") + conclusion)
		} else {
			messages = [.finished(Translation(english: evalCase.english, issues: [TranslationIssue(severity: .error, message: "Expected a claim")]))]
		}
		#expect(Scoring.score(run(messages), for: evalCase).outcome == .pass)
	}

	@Test func countsFormalizeAttemptsAndVerifyWarnings() {
		let messages: [TranslateServerMessage] = [
			.event(.started(step: .formalize, attempt: 1)),
			.event(.retrying(problems: ["Premise 1 'X→': Expected statement after '→'"], attempt: 1)),
			.event(.started(step: .formalize, attempt: 2)),
			.event(.started(step: .verify, attempt: 1)),
		] + finished("X→Y\nX\n∴Y", issues: [TranslationIssue(severity: .warning, message: "Reads as a different claim")]).suffix(1)
		let evalRun = run(messages)

		#expect(evalRun.formalizeAttempts == 2)
		#expect(evalRun.verifyRan)
		#expect(evalRun.hasVerifyWarnings)
		#expect(Scoring.score(evalRun, for: modusPonens).problem == "Reads as a different claim")
	}
}
