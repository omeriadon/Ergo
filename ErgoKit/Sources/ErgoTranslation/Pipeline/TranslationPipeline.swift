//
//  TranslationPipeline.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoLogic
import Foundation

/// English → logic, step by step:
/// 1. Validate locally, so gibberish never reaches a model
/// 2. Gate: is it an argument, claims, or neither
/// 3. Breakdown: premises, conclusion, and up to six simple claims with descriptors
/// 4. Formalize, then compile with `LogicParser`, feeding errors back for another try
/// 5. Verify: read the logic back with `LogicEnglish` and ask whether it still means the same,
///    feeding differences back the same way
public struct TranslationPipeline: Sendable {
	public let backend: any TranslationBackend
	public let letters: [String]

	public init(backend: any TranslationBackend, letters: [String]) {
		self.backend = backend
		self.letters = letters
	}

	/// Throws only when the backend can't be reached or the task is cancelled, everything else ends up in `issues`.
	/// `events` hears about each step as it happens.
	public func translate(
		_ english: String,
		events: @Sendable (TranslationEvent) async -> Void = { _ in }
	) async throws -> Translation {
		var result = Translation(english: english)
		let letters = LogicLetters.resolved(letters)
		var attempts: [TranslationStep: Int] = [:]

		// Every model call goes through here, so each one is announced and can be cancelled
		func run<Stage: TranslationStage>(_ stage: Stage.Type, _ step: TranslationStep, _ input: Stage.Input) async throws -> Stage.Output {
			try Task.checkCancellation()
			attempts[step, default: 0] += 1
			await events(.started(step: step, attempt: attempts[step, default: 0]))
			return try await backend.run(stage, input)
		}

		func failure(_ message: String, notes: [String] = []) -> Translation {
			var failed = Translation(english: english)
			failed.issues = [TranslationIssue(severity: .error, message: message)]
				+ notes.map { TranslationIssue(severity: .warning, message: $0) }
			return failed
		}

		if let problem = EnglishValidator.problem(with: english) {
			return failure(problem)
		}

		let gate = try await run(GateStage.self, .gate, GateStage.Input(english: english))
		guard gate.kind != .neither else {
			return failure(gate.reason.isEmpty ? "Expected an argument or a claim" : gate.reason)
		}

		let breakdown = try await run(
			BreakdownStage.self,
			.breakdown,
			BreakdownStage.Input(
				english: english,
				maximumClaims: LogicLetters.slots.count,
				descriptorWordLimit: LogicLetters.descriptorWordLimit
			)
		)
		guard !breakdown.claims.isEmpty else {
			return failure("Expected at least one claim")
		}
		guard breakdown.claims.count <= LogicLetters.slots.count else {
			return failure("Expected at most \(LogicLetters.slots.count) separate claims, found \(breakdown.claims.count)")
		}

		result.descriptors = LogicLetters.slots.map { slot in
			let index = slot - LogicLetters.slots.lowerBound
			return breakdown.claims.indices.contains(index) ? LogicLetters.sanitizedDescriptor(breakdown.claims[index].descriptor) : ""
		}

		let conclusion = gate.kind == .argument && !breakdown.conclusion.isEmpty ? breakdown.conclusion : nil
		await events(.foundClaims(premises: breakdown.premises, conclusion: conclusion ?? "", descriptors: result.descriptors))

		var previous: FormalizeStage.Output?
		var problems: [String] = []

		for attempt in stride(from: 1, through: backend.policy.attempts, by: 1) {
			/// Only problems that feed into another try are worth announcing
			func retry(_ rejected: [String]) async {
				problems = rejected
				if attempt < backend.policy.attempts {
					await events(.retrying(problems: rejected, attempt: attempt))
				}
			}

			let output = try await run(
				FormalizeStage.self,
				.formalize,
				FormalizeStage.Input(
					english: english,
					premises: breakdown.premises,
					conclusion: conclusion,
					letters: zip(letters, breakdown.claims).map { FormalizeStage.Input.Letter(letter: $0, meaning: $1.meaning) },
					grammar: LogicGrammar.reference(letters: letters),
					grammarVersion: LogicGrammar.version,
					previous: previous,
					problems: problems
				)
			)
			previous = output

			let compiled = compile(output, premises: breakdown.premises.count, hasConclusion: conclusion != nil, letters: letters)
			guard let entries = compiled.entries else {
				await retry(compiled.problems)
				continue
			}

			// Keep the last version that compiled, even if a later try doesn't
			result.entries = entries
			result.issues = []
			await events(.drafted(entries: entries, attempt: attempt))

			guard backend.policy.verifies else { return result }

			let reading = LogicEnglish.text(for: LogicParser.parse(entries).argument, letters: letters, descriptors: result.descriptors)
			let verdict = try await run(VerifyStage.self, .verify, VerifyStage.Input(english: english, reading: reading))
			if verdict.matches {
				return result
			}

			await retry(verdict.differences)
			result.issues = verdict.differences.map { TranslationIssue(severity: .warning, message: $0) }
		}

		if result.entries.isEmpty {
			return failure("Couldn't write this as valid logic", notes: problems)
		}
		return result
	}

	/// Each statement on its own line, then ∴ and the conclusion. Problems are worded for the model to fix.
	private func compile(
		_ output: FormalizeStage.Output,
		premises expectedPremises: Int,
		hasConclusion: Bool,
		letters: [String]
	) -> (entries: [LogicKeyboardEntry]?, problems: [String]) {
		let vocabulary = LogicInputVocabulary(letters: letters)
		var problems: [String] = []
		var statements: [[LogicKeyboardEntry]] = []

		if output.premises.count != expectedPremises {
			problems.append("Expected \(expectedPremises) premises, found \(output.premises.count)")
		}

		var labelled = output.premises.enumerated().map { ("Premise \($0.offset + 1)", $0.element) }
		if hasConclusion {
			labelled.append(("Conclusion", output.conclusion))
		}

		for (label, text) in labelled {
			let unknown = text.filter { !$0.isWhitespace && vocabulary.entry(for: $0) == nil }
			guard unknown.isEmpty else {
				problems.append("\(label) '\(text)': Unknown symbols '\(unknown)'")
				continue
			}

			let entries = text.compactMap { vocabulary.entry(for: $0) }
			let parse = LogicParser.parse(entries)

			if let diagnostic = parse.diagnostics.first {
				problems.append("\(label) '\(text)': \(diagnostic.problem.message(letters: letters))")
			} else if parse.marker != nil || parse.argument.premises.count != 1 {
				problems.append("\(label) '\(text)': Expected exactly one statement")
			} else {
				statements.append(entries)
			}
		}

		guard problems.isEmpty else {
			return (nil, problems)
		}

		var entries: [LogicKeyboardEntry] = []
		for (index, statement) in statements.enumerated() {
			if index > 0 {
				entries.append(.delimiter("\n"))
			}
			if hasConclusion, index == statements.count - 1 {
				entries.append(.symbol("∴"))
			}
			entries += statement
		}

		return (entries, [])
	}
}
