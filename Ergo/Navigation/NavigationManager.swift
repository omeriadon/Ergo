//
//  NavigationManager.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

@MainActor
@Observable
final class NavigationManager {
	/// Currently visible tab
	var selectedTab: AppTab = .check

	// Independent navigation histories
	var libraryPath: [ItemRoute] = []
	var debatePath: [DebateRoute] = []

	/// Currently presented sheet
	var presentedSheet: AppSheet?

	// MARK: - Item Navigation

	func open(_ route: ItemRoute, from _: ItemTab) {
		selectedTab = .library
		libraryPath.append(route)
	}

	// MARK: - Debate Navigation

	func open(_ route: DebateRoute) {
		selectedTab = .debate
		debatePath.append(route)
	}

	// MARK: - Sheets

	func presentSheet(_ sheet: AppSheet) {
		presentedSheet = sheet
	}

	func dismissSheet() {
		presentedSheet = nil
	}

	// MARK: - Reset Navigation

	func reset(_ tab: AppTab) {
		switch tab {
			case .check:
				break
			case .debate:
				debatePath.removeAll()
			case .library:
				libraryPath.removeAll()
		}
	}
}
