//
//  LogicPage.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import Foundation

/// One argument on the Check tab: statements joined by "premise of" links, and what each letter stands for.
/// The descriptors are shared by every statement, which is what makes `P` in one box the same claim as `P` in another.
///
/// It always holds at least one statement, so the Check tab is never empty.
struct LogicPage: Codable, Hashable, Identifiable, Defaults.Serializable {
	var id = UUID()
	var created = Date.now
	var modified = Date.now

	/// One per letter slot, at most four words each
	var descriptors = LogicLetters.emptyDescriptors

	var statements = [Statement()]
	var links: [Link] = []

	/// Nothing written yet, so the page stays out of the list. Where boxes sit isn't writing.
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

	/// The first English in reading order, else the first logic, else "Untitled"
	func title(letters: [String]) -> String {
		let ordered = map.topologicalOrder().compactMap { statement($0) }
		return ordered.lazy.compactMap(\.englishLine).first
			?? ordered.lazy.compactMap { $0.logicLine(letters: letters) }.first
			?? "Untitled"
	}

	/// Names the slots that are still free and leaves the rest as they are, so a translation of one statement
	/// never renames what another one relies on
	mutating func merge(descriptors new: [String]) {
		for slot in descriptors.indices where descriptors[slot].isEmpty && new.indices.contains(slot) {
			descriptors[slot] = LogicLetters.sanitizedDescriptor(new[slot])
		}
	}
}
