import Foundation

enum LogicKeyboardEntry: Hashable, Sendable {
	case variable(String)
	case symbol(String)
	case delimiter(String)

	var glyph: String {
		switch self {
			case let .variable(value), let .symbol(value), let .delimiter(value):
				value
		}
	}

	var id: String {
		switch self {
			case let .variable(value):
				"variable.\(value)"
			case let .symbol(value):
				"symbol.\(value)"
			case let .delimiter(value):
				"delimiter.\(value)"
		}
	}

	var isLetter: Bool {
		if case .variable = self {
			return true
		}
		return false
	}

	static let topRows: [[LogicKeyboardEntry]] = [
		[.symbol("="), .symbol("∈"), .symbol("∪"), .symbol("∩"), .symbol("⊂"), .symbol("∅")],
		[.symbol("∴"), .symbol("∵"), .symbol("≔"), .symbol("∎")],
	]

	static let bottomRows: [[LogicKeyboardEntry]] = [
		[.symbol("↔"), .symbol("⊕"), .symbol("⊤"), .symbol("∀"), .symbol("∃")],
		[.symbol("□"), .symbol("◇"), .symbol("⊢"), .symbol("⊨"), .symbol("⇔")],
	]

	static let structuralRow: [LogicKeyboardEntry] = [
		.symbol("¬"), .symbol("∧"), .symbol("∨"), .symbol("→"),
		.delimiter("("), .delimiter(")"), .delimiter("["), .delimiter("]"),
	]

	static let fixedEntries: [LogicKeyboardEntry] = structuralRow + [
		.delimiter(","), .delimiter("\n"),
	]

	static func configuredLetters(_ values: [String]) -> [LogicKeyboardEntry] {
		values.prefix(6).filter { $0.count == 1 && $0.first?.isLetter == true }.map { .variable($0) }
	}

	static func alternate(for glyph: String) -> LogicKeyboardEntry? {
		switch glyph {
			case "=": .symbol("≠")
			case "∈": .symbol("∉")
			case "⊂": .symbol("⊆")
			default: nil
		}
	}
}

struct LogicInputVocabulary: Sendable {
	let availableEntries: [LogicKeyboardEntry]
	let entries: Set<String>

	init(logicLetters: [String]) {
		let base = LogicKeyboardEntry.fixedEntries
			+ LogicKeyboardEntry.topRows.flatMap(\.self)
			+ LogicKeyboardEntry.bottomRows.flatMap(\.self)
			+ LogicKeyboardEntry.configuredLetters(logicLetters)
		availableEntries = base + base.compactMap { LogicKeyboardEntry.alternate(for: $0.glyph) }
		entries = Set(availableEntries.map(\.glyph))
	}

	func accepts(_ text: String) -> Bool {
		text.allSatisfy { entries.contains(String($0)) }
	}

	func entry(for glyph: String) -> LogicKeyboardEntry? {
		availableEntries.first { $0.glyph == glyph }
	}
}

struct LogicEditorSymbolDefinition: Hashable, Sendable {
	let id: String
	let glyph: String
	let name: String
	let summary: String
	let semanticSymbol: SymbolEnum?
}

enum LogicEditorSymbols {
	static func definitions(
		catalogSymbols: [LogicSymbol]
	) -> [LogicEditorSymbolDefinition] {
		var definitions: [LogicEditorSymbolDefinition] = []
		var seenGlyphs = Set<String>()
		for symbol in catalogSymbols {
			for glyph in [symbol.glyph] + symbol.alternateGlyphs {
				guard !glyph.isEmpty, seenGlyphs.insert(glyph).inserted else {
					continue
				}
				definitions.append(
					LogicEditorSymbolDefinition(
						id: symbol.id + ":" + glyph,
						glyph: glyph,
						name: symbol.name,
						summary: symbol.summary,
						semanticSymbol: Self.symbolEnum(for: symbol.id)
					)
				)
			}
		}

		for symbol in SymbolEnum.allCases {
			guard seenGlyphs.insert(symbol.glyph).inserted else {
				continue
			}
			definitions.append(
				LogicEditorSymbolDefinition(
					id: symbol.rawValue,
					glyph: symbol.glyph,
					name: symbol.name,
					summary: "",
					semanticSymbol: symbol
				)
			)
		}

		return definitions
	}

	private static func symbolEnum(for id: String) -> SymbolEnum? {
		let rawValue = id.replacingOccurrences(of: "-", with: "")
		return SymbolEnum.allCases.first { symbol in
			let candidate = symbol.rawValue.replacingOccurrences(of: "-", with: "")
			return candidate.caseInsensitiveCompare(rawValue) == .orderedSame
		}
	}
}
