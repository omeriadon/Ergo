//
//  AskThinkingWord.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import Foundation

/// What the line above an answer says it was doing: "Contemplating" while it runs and "Contemplated" once it's done.
struct AskThinkingWord: Hashable {
	let gerund: String
	let past: String

	private init(_ gerund: String, _ past: String) {
		self.gerund = gerund
		self.past = past
	}

	/// Worked out from the answer's id and not stored, so an answer keeps its word from start to finish and after a relaunch
	static func `for`(_ id: UUID) -> AskThinkingWord {
		let sum = withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 + Int($1) } }
		return all[sum % all.count]
	}

	private static let all = [
		AskThinkingWord("Contemplating", "Contemplated"),
		AskThinkingWord("Pondering", "Pondered"),
		AskThinkingWord("Ruminating", "Ruminated"),
		AskThinkingWord("Cogitating", "Cogitated"),
		AskThinkingWord("Musing", "Mused"),
		AskThinkingWord("Deliberating", "Deliberated"),
		AskThinkingWord("Mulling", "Mulled"),
		AskThinkingWord("Reflecting", "Reflected"),
		AskThinkingWord("Meditating", "Meditated"),
		AskThinkingWord("Reasoning", "Reasoned"),
		AskThinkingWord("Puzzling", "Puzzled"),
		AskThinkingWord("Noodling", "Noodled"),
		AskThinkingWord("Wondering", "Wondered"),
		AskThinkingWord("Considering", "Considered"),
		AskThinkingWord("Weighing", "Weighed"),
		AskThinkingWord("Untangling", "Untangled"),
		AskThinkingWord("Unravelling", "Unravelled"),
		AskThinkingWord("Deducing", "Deduced"),
		AskThinkingWord("Inferring", "Inferred"),
		AskThinkingWord("Synthesising", "Synthesised"),
		AskThinkingWord("Distilling", "Distilled"),
		AskThinkingWord("Percolating", "Percolated"),
		AskThinkingWord("Simmering", "Simmered"),
		AskThinkingWord("Brewing", "Brewed"),
		AskThinkingWord("Stewing", "Stewed"),
		AskThinkingWord("Marinating", "Marinated"),
		AskThinkingWord("Steeping", "Steeped"),
		AskThinkingWord("Incubating", "Incubated"),
		AskThinkingWord("Fermenting", "Fermented"),
		AskThinkingWord("Germinating", "Germinated"),
		AskThinkingWord("Philosophising", "Philosophised"),
		AskThinkingWord("Theorising", "Theorised"),
		AskThinkingWord("Hypothesising", "Hypothesised"),
		AskThinkingWord("Speculating", "Speculated"),
		AskThinkingWord("Examining", "Examined"),
		AskThinkingWord("Scrutinising", "Scrutinised"),
		AskThinkingWord("Sifting", "Sifted"),
		AskThinkingWord("Parsing", "Parsed"),
		AskThinkingWord("Perusing", "Perused"),
		AskThinkingWord("Dissecting", "Dissected"),
		AskThinkingWord("Discerning", "Discerned"),
		AskThinkingWord("Fathoming", "Fathomed"),
		AskThinkingWord("Divining", "Divined"),
		AskThinkingWord("Daydreaming", "Daydreamed"),
		AskThinkingWord("Ideating", "Ideated"),
		AskThinkingWord("Crystallising", "Crystallised"),
		AskThinkingWord("Conjuring", "Conjured"),
		AskThinkingWord("Cerebrating", "Cerebrated"),
		AskThinkingWord("Lucubrating", "Lucubrated"),
		AskThinkingWord("Ratiocinating", "Ratiocinated"),
	]
}
