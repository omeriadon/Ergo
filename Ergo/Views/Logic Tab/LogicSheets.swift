//
//  LogicSheets.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
import SwiftUI

/// The sheets that belong to the Logic tab. See `NavigationManager.logicSheet`.
nonisolated enum LogicSheet: Hashable, Identifiable, Codable, Defaults.Serializable {
	case logicLetters

	var id: Self {
		self
	}
}

struct LogicSheetContent: View {
	let sheet: LogicSheet

	var body: some View {
		switch sheet {
			case .logicLetters:
				LogicLettersSheet()
		}
	}
}
