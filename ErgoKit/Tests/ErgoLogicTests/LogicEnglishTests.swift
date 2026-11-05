//
//  LogicEnglishTests.swift
//  ErgoKit
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoLogic
import Testing

/// Reading logic back is exact: compound parts are bracketed, ∧ and ∨ chains are flattened
struct LogicEnglishTests {
	let letters = LogicLetters.defaults
	let vocabulary = LogicInputVocabulary(letters: LogicLetters.defaults)

	func read(_ text: String, descriptors: [String] = LogicLetters.emptyDescriptors) -> String {
		let parse = LogicParser.parse(vocabulary.entries(in: text))
		#expect(parse.diagnostics.isEmpty, "Doesn't parse: \(text)")
		return LogicEnglish.text(for: parse.argument, letters: letters, descriptors: descriptors)
	}

	@Test func descriptorsReadAsClaims() {
		let weather = ["it rains", "the ground is wet", "", "", "", ""]
		#expect(read("X→Y,X∴Y", descriptors: weather) == "If it rains, then the ground is wet.\nIt rains.\nTherefore, the ground is wet.")
	}

	@Test func compoundPartsAreBracketed() {
		#expect(read("¬(X∧Y)") == "It is not the case that (X and Y).")
		#expect(read("¬X") == "It is not the case that X.")
		#expect(read("X∧Y∨Z") == "(X and Y) or Z.")
		#expect(read("X→(Y→Z)") == "If X, then (if Y, then Z).")
		#expect(read("¬X∧Y") == "(It is not the case that X) and Y.")
		#expect(read("X⊕Y") == "Either X or Y, but not both.")
		#expect(read("∀XP(X)") == "For every X, P(X).")
		#expect(read("X∪Y⊂Z") == "(The union of X and Y) is a proper subset of Z.")
	}

	@Test func chainsAreFlattened() {
		#expect(read("X∧Y∧Z") == "X, Y and Z.")
		#expect(read("X∧(Y∧Z)") == "X, Y and Z.")
	}

	@Test func statementsWithoutAConclusion() {
		#expect(read("X\nY") == "X.\nY.")
	}
}
