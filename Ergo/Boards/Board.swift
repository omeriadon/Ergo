//
//  Board.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import Foundation

/// One board: statements holding English, joined by "premise of" links.
///
/// It always holds at least one statement, so the Board tab is never empty.
struct Board: Codable, Hashable, Identifiable, Defaults.Serializable {
	var id = UUID()
	var created = Date.now
	var modified = Date.now

	var statements = [Statement()]
	var links: [Link] = []

	/// Nothing written yet, so the board stays out of the list. Where boxes sit isn't writing.
	var isEmpty: Bool {
		links.isEmpty && statements.allSatisfy(\.isEmpty)
	}

	/// The statements and links as `ErgoLogic` works with them: its validator, layout, text conversions and checks
	var map: ArgumentMap<Statement, Link> {
		get {
			ArgumentMap(statements: statements, links: links)
		}
		set {
			statements = newValue.statements
			links = newValue.links
		}
	}

	func statement(_ id: Statement.ID) -> Statement? {
		statements.first { $0.id == id }
	}

	/// The first English in reading order, else "Untitled"
	var title: String {
		map.topologicalOrder().lazy
			.compactMap { statement($0)?.englishLine }
			.first ?? "Untitled"
	}
}
