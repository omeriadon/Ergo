//
//  Scoring.swift
//  Evals
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

enum Outcome: String, Codable, Sendable, CaseIterable {
	/// Means the same as expected under some renaming of letters, or for neither, turned away with nothing translated
	case pass

	/// Parsed, but says something else
	case wrongMeaning

	/// Gave up on real logic, translated something that isn't, or mixed up an argument and statements
	case wrongKind

	/// A `ServiceError`, or the pipeline couldn't write logic at all
	case failed

	/// Uses something the truth table can't compare, like □ or ∀, so it's counted apart
	case unscorable
}

struct Score: Codable, Sendable {
	let outcome: Outcome

	/// Formulas, like `X → Y, X ∴ Y`
	let expected: String?
	let got: String?

	/// Both read back by `LogicEnglish` with the translation's descriptors. That assumes both lettered claims
	/// by first appearance, which is the convention, so a mismatch here can also mean the letters are just shuffled.
	let expectedReading: String?
	let gotReading: String?

	/// What to look at first: the error, or the first issue the translation came back with
	let problem: String?
}

enum Scoring {
	static func score(_ run: EvalRun, for evalCase: EvalCase) -> Score {
		// Already validated, so this only fails for a corpus the runner wouldn't have started on
		let expected = (try? evalCase.expectedArgument()) ?? nil

		func score(_ outcome: Outcome, got: LogicArgument? = nil, descriptors: [String] = [], problem: String?) -> Score {
			func reading(_ argument: LogicArgument?) -> String? {
				argument.map { LogicEnglish.text(for: $0, letters: Corpus.letters, descriptors: descriptors) }
			}

			return Score(
				outcome: outcome,
				expected: expected.map(text),
				got: got.map(text),
				expectedReading: got == nil ? nil : reading(expected),
				gotReading: reading(got),
				problem: problem
			)
		}

		if let error = run.error {
			return score(.failed, problem: "\(error.code.rawValue): \(error.message)")
		}
		guard let translation = run.translation else {
			return score(.failed, problem: "Expected '.finished' or '.failed', the stream ended without either")
		}

		let firstIssue = translation.issues.first?.message
		let parse = translation.entries.isEmpty ? nil : LogicParser.parse(translation.entries)

		guard let expected else {
			guard let parse else {
				let turnedAway = translation.issues.contains { $0.severity == .error }
				return score(turnedAway ? .pass : .wrongKind, problem: firstIssue ?? "Expected an error, found no issues")
			}
			return score(.wrongKind, got: parse.argument, descriptors: translation.descriptors, problem: "Expected no translation, found some")
		}

		guard let parse else {
			// Gate turning it away is a wrong call about the kind, giving up later is a failure to write it
			return score(run.reachedBreakdown ? .failed : .wrongKind, problem: firstIssue)
		}
		if let diagnostic = parse.diagnostics.first {
			return score(.failed, problem: "Returned logic doesn't parse: \(diagnostic.problem.message(letters: Corpus.letters))")
		}

		let got = parse.argument
		func scored(_ outcome: Outcome, _ fallback: String? = nil) -> Score {
			score(outcome, got: got, descriptors: translation.descriptors, problem: firstIssue ?? fallback)
		}

		switch (expected.conclusion, got.conclusion) {
			case (.some, nil):
				return scored(.wrongKind, "Expected an argument, found statements")
			case (nil, .some):
				return scored(.wrongKind, "Expected statements, found an argument")
			default:
				break
		}

		guard (got.premises + [got.conclusion].compactMap(\.self)).allSatisfy(\.formula.isPropositional) else {
			return scored(.unscorable)
		}
		if LogicEquivalence.mapping(from: expected.joined, to: got.joined) != nil {
			return scored(.pass)
		}
		return scored(.wrongMeaning, "Not equivalent under any renaming of letters")
	}

	static func text(_ argument: LogicArgument) -> String {
		let premises = argument.premises.map { $0.formula.text(letters: Corpus.letters) }.joined(separator: ", ")
		guard let conclusion = argument.conclusion else { return premises }
		return premises + " ∴ " + conclusion.formula.text(letters: Corpus.letters)
	}
}

private extension LogicArgument {
	/// All the premises as one conjunction, so splitting 'X ∧ Y' into two premises (or not) doesn't change the score
	var joined: LogicArgument {
		guard let first = premises.first else { return self }

		let formula = premises.dropFirst().reduce(first.formula) { .and($0, $1.formula) }
		return LogicArgument(premises: [LogicStatement(formula: formula, range: first.range)], conclusion: conclusion)
	}
}
