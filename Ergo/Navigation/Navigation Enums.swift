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

	static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.board: DisplayRepresentation(title: "Board", image: .init(systemName: "flowchart")),
		.logic: DisplayRepresentation(title: "Logic", image: .init(systemName: "function")),
		.ask: DisplayRepresentation(title: "Ask", image: .init(systemName: "bubble.left.and.text.bubble.right")),
		.library: DisplayRepresentation(title: "Library", image: .init(systemName: "books.vertical")),
	]
}

/// Pushed on the Logic tab's list. The editor shows `ScratchpadStore.current`, so the route needs no id.
enum LogicRoute: Hashable, Codable, Defaults.Serializable {
	case scratchpad
}

enum AppSheet: Hashable, Identifiable, Codable, Defaults.Serializable {
	case scanner
	case paste
	case result(id: String)

	case settings(id: String)
	case logicLetters
	case boards
	case shared(SharedItem)
	case breakDownSource(BoardSource.ID)
	case boardPeople(Board.ID)

	/// The invite link's token, kept with the sheet like `shared`'s item, so a link opened before the app was killed still opens
	case joinBoard(String)
	case addToChat(AskAttachment.Content)

	var id: Self {
		self
	}
}
