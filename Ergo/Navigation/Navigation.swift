//
//  Navigation.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import SwiftUI

/// Your four root tabs
enum AppTab: Hashable, Codable, Defaults.Serializable {
	case check
	case debate
	case library
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
	case about(id: String)

	var id: Self {
		self
	}
}
