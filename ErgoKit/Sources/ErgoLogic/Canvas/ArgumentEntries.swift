//
//  ArgumentEntries.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

public enum ArgumentEntriesProblem: Equatable, Sendable, Error {
	case unknownStatement(UUID)

	/// The statement's logic has mistakes. Carries the first one, as entry indices into that statement's own logic.
	case doesNotParse(UUID, LogicDiagnostic)

	/// Several statements, or an argument marker, in a box that holds one claim
	case notOneStatement(UUID)

	public var statement: UUID {
		switch self {
			case let .unknownStatement(id), let .doesNotParse(id, _), let .notOneStatement(id):
				id
		}
	}

	public var message: String {
		switch self {
			case .unknownStatement:
				"Expected a statement on the canvas, found one that does not exist"
			case .doesNotParse:
				"Expected a statement that parses, found a formula with mistakes"
			case .notOneStatement:
				"Expected a single statement, found more than one"
		}
	}
}

/// The argument the checker sees for a statement with incoming links: `premise₁, premise₂ ∴ conclusion`,
/// written from the linked statements' logic.
public struct ArgumentEntries: Equatable, Sendable {
	/// In the same order as the checker's premises, so `LogicFallacyMatch.premises` indices map back to statements
	public let premises: [UUID]
	public let conclusion: UUID
	public let entries: [LogicKeyboardEntry]

	/// Nil when `id` has no premises, or any statement involved has no logic yet.
	/// Premises come in canvas reading order (`ArgumentMap.topologicalOrder`), which is also how `ArgumentText` lists them.
	public static func build(for id: UUID, in map: ArgumentMap<some Any, some Any>) throws(ArgumentEntriesProblem) -> ArgumentEntries? {
		guard let conclusion = map.statement(id) else { throw .unknownStatement(id) }

		let linkedIDs = map.premises(of: id)
		guard !linkedIDs.isEmpty else { return nil }

		if let gone = linkedIDs.first(where: { map.statement($0) == nil }) {
			throw .unknownStatement(gone)
		}

		let linked = Set(linkedIDs)
		let premises = map.topologicalOrder().filter(linked.contains)
		var parts: [[LogicKeyboardEntry]] = []
		var missingLogic = false

		for statement in premises.compactMap({ map.statement($0) }) + [conclusion] {
			if let part = try single(statement.logic, of: statement.id) {
				parts.append(part)
			} else {
				missingLogic = true
			}
		}
		guard !missingLogic else { return nil }

		let entries = Array(parts.dropLast().joined(separator: [.delimiter(",")])) + [.symbol("∴")] + parts[parts.count - 1]

		return ArgumentEntries(premises: premises, conclusion: id, entries: entries)
	}

	/// Runs the checker on `build`. Nil under the same conditions, and for a statement the checker can't be given.
	public static func check(statement id: UUID, in map: ArgumentMap<some Any, some Any>) throws(ArgumentEntriesProblem) -> LogicAnalysis? {
		guard let argument = try build(for: id, in: map) else { return nil }
		return LogicChecker.analyze(argument.entries)
	}

	/// The statement's logic without stray new lines, nil when there is none.
	/// Throws when it holds anything but exactly one statement that parses.
	public static func single(_ logic: [LogicKeyboardEntry], of id: UUID) throws(ArgumentEntriesProblem) -> [LogicKeyboardEntry]? {
		guard let first = logic.firstIndex(where: { $0 != .delimiter("\n") }),
		      let last = logic.lastIndex(where: { $0 != .delimiter("\n") })
		else { return nil }

		let parse = LogicParser.parse(logic)
		if let diagnostic = parse.diagnostics.first {
			throw .doesNotParse(id, diagnostic)
		}

		guard parse.marker == nil, parse.argument.premises.count == 1,
		      parse.argument.premises[0].range == first ..< last + 1
		else { throw .notOneStatement(id) }

		return Array(logic[first ... last])
	}
}
