//
//  Navigation Enums.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import AppIntents
import Defaults
import ErgoShare
import SwiftUI

/// Your four root tabs
enum AppTab: String, Hashable, Codable, Defaults.Serializable, AppEnum {
	case board
	case logic
	case ask
	case library

	static var typeDisplayRepresentation: TypeDisplayRepresentation {
		TypeDisplayRepresentation(name: "Ergo Tab")
	}

	static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.board: DisplayRepresentation(title: "Board", image: .init(systemName: "flowchart")),
		.logic: DisplayRepresentation(title: "Logic", image: .init(systemName: "function")),
		.ask: DisplayRepresentation(title: "Ask", image: .init(systemName: "bubble.left.and.text.bubble.right")),
		.library: DisplayRepresentation(title: "Library", image: .init(systemName: "books.vertical")),
	]
}

/// Pushed on the Logic tab's list. The editor shows `ScratchpadStore.current`, so the route needs no id.
nonisolated enum LogicRoute: Hashable, Codable, Defaults.Serializable {
	case scratchpad
	case course
	case lesson(String)
}

/// The sheets that don't belong to one tab. A tab's own are in `BoardSheet`, `LogicSheet` and `LibrarySheet`.
nonisolated enum AppSheet: Hashable, Identifiable, Codable, Defaults.Serializable {
	case scanner
	case paste
	case result(id: String)

	case settings(id: String)
	case shared(SharedItem)

	/// The invite link's token, kept with the sheet like `shared`'s item, so a link opened before the app was killed still opens
	case joinBoard(String)
	case addToChat(AskAttachment.Content)

	/// What the paid plan adds, and buying it
	case plus

	var id: Self {
		self
	}
}

/// The one sheet on screen, whichever of the app's or a tab's it is
nonisolated enum VisibleSheet: Hashable, Identifiable {
	case app(AppSheet)
	case board(BoardSheet)
	case logic(LogicSheet)
	case library(LibrarySheet)

	var id: Self {
		self
	}
}
