//
//  Corpus.swift
//  Evals
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoLogic
import ErgoTranslation
import Foundation

/// The JSON files in `Corpus/`, each an array of `EvalCase`
enum Corpus {
	struct File: Sendable {
		/// Without the extension, like `conditionals`
		let name: String
		let cases: [EvalCase]
	}

	/// Found from this file rather than the working directory, so `swift run` and `swift test` work from anywhere
	static let root = URL(filePath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.deletingLastPathComponent()

	static let directory = root.appending(path: "Corpus")
	static let results = root.appending(path: "Results")

	/// Every expected formula is written with these, whatever the app's letters are
	static let letters = LogicLetters.defaults

	/// One per row of the English conventions table in `Plans/README.md`, each needing at least 3 cases
	static let conventionTags = ["conditional", "iff", "unless", "either-or", "xor", "neither", "not-both", "but", "since-because"]

	/// Rejected by `EnglishValidator` before any model sees it, rather than by the gate
	static let localTag = "local"

	/// Exactly the cases whose verdict is invalid
	static let fallacyTag = "fallacy"

	static func load(from directory: URL = directory) throws -> [File] {
		let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
			.filter { $0.pathExtension == "json" }
			.sorted { $0.lastPathComponent < $1.lastPathComponent }

		return try urls.map { url in
			let name = url.deletingPathExtension().lastPathComponent
			do {
				return try File(name: name, cases: JSONDecoder().decode([EvalCase].self, from: Data(contentsOf: url)))
			} catch {
				throw EvalError("\(url.lastPathComponent): \(error)")
			}
		}
	}

	/// One statement exactly as the corpus spells it, held to the same rules as a model's formalize output
	static func formula(_ text: String) throws -> LogicFormula {
		let vocabulary = LogicInputVocabulary(letters: letters)
		let unknown = text.filter { !$0.isWhitespace && vocabulary.entry(for: $0) == nil }
		guard unknown.isEmpty else {
			throw EvalError("'\(text)': Unknown symbols '\(unknown)'")
		}

		let parse = LogicParser.parse(text.compactMap { vocabulary.entry(for: $0) })
		if let diagnostic = parse.diagnostics.first {
			throw EvalError("'\(text)': \(diagnostic.problem.message(letters: letters))")
		}
		guard parse.marker == nil, parse.argument.premises.count == 1 else {
			throw EvalError("'\(text)': Expected exactly one statement")
		}
		return parse.argument.premises[0].formula
	}
}

struct EvalError: Error, CustomStringConvertible {
	let description: String

	init(_ description: String) {
		self.description = description
	}
}

// MARK: - Validation

/// Each check on its own, so the tests can name which rule a case breaks.
/// An empty list means the case is fine.
extension EvalCase {
	var problems: [String] {
		shapeProblems + formulaProblems + letterProblems + verdictProblems + englishProblems
	}

	var shapeProblems: [String] {
		var problems: [String] = []

		if id.isEmpty || id.contains(where: { !($0.isLowercase || $0.isNumber || $0 == "-") }) {
			problems.append("Expected an id in lowercase-kebab-case, found '\(id)'")
		}
		if tags.isEmpty {
			problems.append("Expected at least one tag")
		}

		switch kind {
			case .neither:
				if expected != nil {
					problems.append("Expected no 'expected' for neither")
				}
				if verdict != nil {
					problems.append("Expected no verdict for neither")
				}
			case .statements:
				if expected?.premises.isEmpty ?? true {
					problems.append("Expected at least one statement")
				}
				if expected?.conclusion.isEmpty == false {
					problems.append("Expected an empty conclusion for statements")
				}
				if verdict != nil {
					problems.append("Expected no verdict for statements")
				}
			case .argument:
				if expected?.premises.isEmpty ?? true {
					problems.append("Expected at least one premise")
				}
				if expected?.conclusion.isEmpty ?? true {
					problems.append("Expected a conclusion for an argument")
				}
		}

		if tags.contains(Corpus.fallacyTag) != (verdict == .invalid) {
			problems.append("Expected the '\(Corpus.fallacyTag)' tag exactly when the verdict is invalid")
		}
		return problems
	}

	var formulaProblems: [String] {
		formulaTexts.compactMap { text in
			do {
				_ = try Corpus.formula(text)
				return nil
			} catch {
				return "\(error)"
			}
		}
	}

	/// At most six, and X Y Z… with none skipped, which catches a slip like writing Q for Z
	var letterProblems: [String] {
		let vocabulary = LogicInputVocabulary(letters: Corpus.letters)
		let slots = Set(formulaTexts.joined().compactMap { character -> Int? in
			guard case let .variable(slot) = vocabulary.entry(for: character) else { return nil }
			return slot
		})

		guard slots.count <= LogicLetters.slots.count else {
			return ["Expected at most \(LogicLetters.slots.count) letters, found \(slots.count)"]
		}
		guard slots == Set(1 ..< 1 + slots.count) else {
			let used = slots.sorted().map { LogicLetters.letter(for: $0, in: Corpus.letters) }.joined(separator: " ")
			return ["Expected letters from X with none skipped, found '\(used)'"]
		}
		return []
	}

	var verdictProblems: [String] {
		guard let verdict else { return [] }
		guard let actual = checkedVerdict else {
			return ["Expected verdict '\(verdict.rawValue)', the checker can't decide"]
		}
		return actual == verdict ? [] : ["Expected verdict '\(verdict.rawValue)', the checker says '\(actual.rawValue)'"]
	}

	/// Anything meant for a model has to get past the validator, and anything tagged local has to be stopped by it
	var englishProblems: [String] {
		let problem = EnglishValidator.problem(with: english)

		switch (kind, tags.contains(Corpus.localTag)) {
			case (.neither, true):
				return problem == nil ? ["Expected EnglishValidator to reject a case tagged '\(Corpus.localTag)'"] : []
			case (_, false):
				return problem.map { ["EnglishValidator rejects it: \($0)"] } ?? []
			case (_, true):
				return ["Expected '\(Corpus.localTag)' only on neither"]
		}
	}

	// MARK: - Expected logic

	private var formulaTexts: [String] {
		guard let expected else { return [] }
		return expected.premises + (expected.conclusion.isEmpty ? [] : [expected.conclusion])
	}

	/// Nil for neither. Throws when a formula doesn't parse, which the offline tests rule out.
	func expectedArgument() throws -> LogicArgument? {
		guard let expected else { return nil }

		return try LogicArgument(
			premises: expected.premises.map { try LogicStatement(formula: Corpus.formula($0), range: 0 ..< 0) },
			conclusion: expected.conclusion.isEmpty ? nil : LogicStatement(formula: Corpus.formula(expected.conclusion), range: 0 ..< 0)
		)
	}

	/// What `LogicChecker` makes of the expected argument, nil without a conclusion or when it can't decide
	var checkedVerdict: Verdict? {
		guard let expected, !expected.conclusion.isEmpty else { return nil }

		let text = expected.premises.joined(separator: "\n") + "\n∴" + expected.conclusion
		switch LogicChecker.analyze(LogicInputVocabulary(letters: Corpus.letters).entries(in: text)).verdict {
			case .valid:
				return .valid
			case .invalid:
				return .invalid
			case .undecided, nil:
				return nil
		}
	}
}
