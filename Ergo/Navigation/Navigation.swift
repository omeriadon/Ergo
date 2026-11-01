//
//  Navigation.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Observation
import SwiftUI

/// Your four root tabs
enum AppTab: Hashable {
	case check
	case debate
	case library
}

/// Exclusive to Debate
enum DebateRoute: Hashable {
	case conversation(id: String)
	case argument(id: String)
	case participant(id: String)
	case summary(id: String)
}

/// all the content middle views library can go to
enum LibraryContent: Hashable {
	case biases
	case concepts
	case fallacies
	case symbols
	case paradoxes
	case philosophers
	case razors
}

/// the actual library route, middle plus detail
enum LibraryRoute: Hashable {
	case category(LibraryContent)
	case detail(category: LibraryContent, id: String)
}

enum AppSheet: Hashable, Identifiable {
	case scanner
	case paste
	case result(id: String)

	case createDebate
	case settings(id: String)
	case about(id: String)

	var id: Self {
		self
	}
}
