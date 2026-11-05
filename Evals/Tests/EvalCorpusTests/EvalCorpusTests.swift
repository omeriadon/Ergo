//
//  EvalCorpusTests.swift
//  Evals
//
//  Created by Adon Omeri on 5/11/2026.
//

@testable import ErgoEval
import Testing

extension EvalCase: CustomTestStringConvertible {
	public var testDescription: String {
		id
	}
}

/// Offline, no server: the answer key has to be right before anything can be scored against it
struct EvalCorpusTests {
	static let cases = ((try? Corpus.load()) ?? []).flatMap(\.cases)

	@Test func everyFileDecodes() throws {
		let files = try Corpus.load()

		#expect(files.map(\.name) == [
			"conditionals", "connectives", "fallacies", "negation-scope",
			"rejections", "statements", "syllogisms", "tricky",
		])
		#expect(files.allSatisfy { !$0.cases.isEmpty })
	}

	@Test func idsAreUnique() {
		let ids = Self.cases.map(\.id)
		let repeated = Set(ids.filter { id in ids.count { $0 == id } > 1 })
		#expect(repeated.isEmpty, "Repeated ids: \(repeated.sorted())")
	}

	@Test(arguments: cases) func isShapedForItsKind(_ evalCase: EvalCase) {
		#expect(evalCase.shapeProblems.isEmpty, "\(evalCase.shapeProblems)")
	}

	@Test(arguments: cases) func expectedFormulasParseAsOneStatementEach(_ evalCase: EvalCase) {
		#expect(evalCase.formulaProblems.isEmpty, "\(evalCase.formulaProblems)")
	}

	@Test(arguments: cases) func usesAtMostSixLettersInOrder(_ evalCase: EvalCase) {
		#expect(evalCase.letterProblems.isEmpty, "\(evalCase.letterProblems)")
	}

	@Test(arguments: cases) func verdictMatchesTheChecker(_ evalCase: EvalCase) {
		#expect(evalCase.verdictProblems.isEmpty, "\(evalCase.verdictProblems)")
	}

	@Test(arguments: cases) func englishGetsPastTheValidator(_ evalCase: EvalCase) {
		#expect(evalCase.englishProblems.isEmpty, "\(evalCase.englishProblems)")
	}

	// MARK: - Coverage

	@Test(arguments: Corpus.conventionTags) func everyConventionHasThreeCases(_ tag: String) {
		#expect(Self.cases.count { $0.tags.contains(tag) } >= 3)
	}

	@Test func enoughInvalidArgumentsAndRejections() {
		#expect(Self.cases.count { $0.verdict == .invalid } >= 10)
		#expect(Self.cases.count { $0.kind == .neither } >= 8)
	}
}
