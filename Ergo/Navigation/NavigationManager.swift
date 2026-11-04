//
//  NavigationManager.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import SwiftUI

@MainActor
@Observable
final class NavigationManager {
	/// Currently visible tab
	var selectedTab: AppTab = .check {
		didSet {
			Defaults[.selectedTab] = selectedTab
		}
	}

	/// Independent navigation histories
	var libraryPath: [LibraryRoute] = [] {
		didSet {
			Defaults[.libraryPath] = libraryPath
		}
	}

	var debatePath: [DebateRoute] = [] {
		didSet {
			Defaults[.debatePath] = debatePath
		}
	}

	/// Currently presented sheet
	var presentedSheet: AppSheet? {
		didSet {
			Defaults[.presentedSheet] = presentedSheet
		}
	}

	func open(_ route: DebateRoute) {
		selectedTab = .debate
		debatePath.append(route)
	}

	func openLibrary(_ route: LibraryRoute) {
		selectedTab = .library
		libraryPath.append(route)
	}

	func presentSheet(_ sheet: AppSheet) {
		presentedSheet = sheet
	}

	func dismissSheet() {
		presentedSheet = nil
	}

	func openLibraryEntry(category: LibraryContent, id: String) {
		selectedTab = .library
		libraryPath.append(.detail(category: category, id: id))
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

	func startup() {
		presentedSheet = Defaults[.presentedSheet]
		selectedTab = Defaults[.selectedTab]
		libraryPath = Defaults[.libraryPath]
		debatePath = Defaults[.debatePath]
	}
}
