//
//  EvalCase.swift
//  Evals
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation

/// Some English and what it should translate to, one entry in a `Corpus/` file
struct EvalCase: Codable, Hashable, Sendable {
	/// What the gate should decide
	enum Kind: String, Codable, Sendable {
		case argument, statements, neither
	}

	enum Verdict: String, Codable, Sendable {
		case valid, invalid
	}

	/// Written with the default letters X Y Z P Q R, in order of first appearance in the English.
	/// Any equivalent spelling is fine, since scoring is by meaning.
	struct Expected: Codable, Hashable, Sendable {
		let premises: [String]

		/// Empty for statements
		let conclusion: String
	}

	let id: String
	let english: String
	let kind: Kind

	/// Nil for neither
	let expected: Expected?

	/// Checked against `LogicChecker` offline, so the corpus can't hold a wrong answer key
	let verdict: Verdict?

	let tags: [String]

	/// Why the case exists, when it isn't obvious
	let note: String?
}
