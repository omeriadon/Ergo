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
