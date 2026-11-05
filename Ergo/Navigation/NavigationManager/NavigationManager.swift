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
	// MARK: - selectedTab

	var selectedTab: AppTab = .check {
		didSet {
			Defaults[.selectedTab] = selectedTab
		}
	}

	// MARK: - libraryPath

	var libraryPath: [LibraryRoute] = [] {
		didSet {
			Defaults[.libraryPath] = libraryPath
		}
	}

	// MARK: - debatePath

	var debatePath: [DebateRoute] = [] {
		didSet {
			Defaults[.debatePath] = debatePath
		}
	}

	// MARK: - presentedSheet

	var presentedSheet: AppSheet? {
		didSet {
			Defaults[.presentedSheet] = presentedSheet
		}
	}

	// MARK: - listStates

	let listStates: [LibraryContent: LibraryListState] = Dictionary(
		uniqueKeysWithValues: LibraryContent.allCases.map { category in
			(category, LibraryListState())
		}
	)

	// MARK: - symbolFilters

	var symbolFilters: [SymbolSearchToken] = []

	// MARK: - libraryTagFilters

	var libraryTagFilters: [LibraryContent: [String]] = [:]

	// MARK: - libraryGeneralSearchText

	var libraryGeneralSearchText = "" {
		didSet {
			Defaults[.libraryGeneralSearchText] = libraryGeneralSearchText
		}
	}

	// MARK: - open()

	func open(_ route: DebateRoute) {
		selectedTab = .debate
		debatePath.append(route)
	}

	// MARK: - openLibrary

	func openLibrary(_ route: LibraryRoute) {
		selectedTab = .library
		libraryPath.append(route)
	}

	// MARK: - presentSheet

	func presentSheet(_ sheet: AppSheet) {
		presentedSheet = sheet
	}

	// MARK: - dismissSheet

	func dismissSheet() {
		presentedSheet = nil
	}

	// MARK: - openLibraryEntry

	func openLibraryEntry(category: LibraryContent, id: String) {
		selectedTab = .library
		// A sheet left open would hide the page, so the link would look like it did nothing
		presentedSheet = nil

		let route = LibraryRoute.detail(category: category, id: id)
		if libraryPath.last != route {
			libraryPath.append(route)
		}
	}

	// MARK: - reset()

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

	// MARK: - startup()

	func startup() {
		presentedSheet = Defaults[.presentedSheet]
		selectedTab = Defaults[.selectedTab]
		libraryPath = Defaults[.libraryPath]
		debatePath = Defaults[.debatePath]
	}
}
