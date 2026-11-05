//
//  Navigation Enums.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import AppIntents
import Defaults
import SwiftUI

/// Your four root tabs
enum AppTab: String, Hashable, Codable, Defaults.Serializable, AppEnum {
	case check
	case debate
	case library

	static var typeDisplayRepresentation: TypeDisplayRepresentation {
		TypeDisplayRepresentation(name: "Ergo Tab")
	}

	static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.check: DisplayRepresentation(title: "Check", image: .init(systemName: "checkmark.seal")),
		.debate: DisplayRepresentation(title: "Debate", image: .init(systemName: "bubble.left.and.text.bubble.right")),
		.library: DisplayRepresentation(title: "Library", image: .init(systemName: "books.vertical")),
	]
}

/// Exclusive to Debate
enum DebateRoute: Hashable, Codable, Defaults.Serializable {
	case conversation(id: String)
	case argument(id: String)
	case participant(id: String)
	case summary(id: String)
}

enum AppSheet: Hashable, Identifiable, Codable, Defaults.Serializable {
	case scanner
	case paste
	case result(id: String)

	case createDebate
	case settings(id: String)
	case logicLetters
	case pages

	var id: Self {
		self
	}
}
