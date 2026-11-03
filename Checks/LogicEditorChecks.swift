import Foundation

let letters = ["X", "Y", "Z", "P", "Q", "R"]
let vocabulary = LogicInputVocabulary(logicLetters: letters)
let keyboardEntries = LogicKeyboardEntry.configuredLetters(letters)
	+ LogicKeyboardEntry.topRows.flatMap(\.self)
	+ LogicKeyboardEntry.bottomRows.flatMap(\.self)
	+ LogicKeyboardEntry.fixedEntries
for entry in keyboardEntries {
	precondition(vocabulary.accepts(entry.glyph))
	precondition(vocabulary.entry(for: entry.glyph) == entry)
	if let alternate = LogicKeyboardEntry.alternate(for: entry.glyph) {
		precondition(vocabulary.accepts(alternate.glyph))
		precondition(vocabulary.entry(for: alternate.glyph) == alternate)
	}
}

precondition(vocabulary.accepts(""))
precondition(vocabulary.accepts("X∧Y→(P∨Q),\nR≠X"))
for invalid in ["A", "X A", "X1", "X🙂", "X\u{FFFC}", "X\t", "X⊥", "X∧́", "X\r"] {
	precondition(!vocabulary.accepts(invalid), "Accepted invalid input: \(invalid)")
}

precondition(LogicKeyboardEntry.configuredLetters([]).isEmpty)
precondition(LogicKeyboardEntry.configuredLetters(["", "AB", "🙂"]).isEmpty)
let custom = LogicInputVocabulary(logicLetters: ["𝑃", "é"])
precondition(custom.accepts("𝑃∧é\n"))
precondition(!custom.accepts("X"))
precondition(LogicInputVocabulary(logicLetters: ["A", "B", "C", "D", "E", "F", "G"]).accepts("F"))
precondition(!LogicInputVocabulary(logicLetters: ["A", "B", "C", "D", "E", "F", "G"]).accepts("G"))
precondition(vocabulary.entry(for: "∧") == .symbol("∧"))
precondition(vocabulary.entry(for: "(") == .delimiter("("))
precondition(vocabulary.entry(for: "X") == .variable("X"))
print("Logic editor checks passed: every keyboard entry and alternate, configured letters, entry identity, newline, empty deletion, and invalid/Unicode input boundaries.")
