//
//  NavigationManager.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import ErgoShare
import SwiftUI

@MainActor
@Observable
final class NavigationManager {
	// MARK: - selectedTab

	var selectedTab: AppTab = .board {
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

	var askThreadSelected: String? {
		didSet {
			Defaults[.askThreadSelected] = askThreadSelected
		}
	}

	// MARK: - logicPath

	var logicPath: [LogicRoute] = [] {
		didSet {
			Defaults[.logicPath] = logicPath
		}
	}

	// MARK: - presentedSheet

	/// A sheet that doesn't belong to one tab. It's over whichever tab is showing.
	var presentedSheet: AppSheet? {
		didSet {
			Defaults[.presentedSheet] = presentedSheet
		}
	}

	// MARK: - Each tab's sheet

	// Each tab keeps its own, and it only shows while that tab does. Leaving a tab takes its sheet away, and coming back
	// brings it back.

	var boardSheet: BoardSheet? {
		didSet {
			Defaults[.boardSheet] = boardSheet
		}
	}

	var logicSheet: LogicSheet? {
		didSet {
			Defaults[.logicSheet] = logicSheet
		}
	}

	var librarySheet: LibrarySheet? {
		didSet {
			Defaults[.librarySheet] = librarySheet
		}
	}

	// MARK: - onboarding

	/// Set at startup from `Defaults[.firstRunFinished]`, and only cleared by `finishOnboarding()`. While it's set the
	/// onboarding sheet is the one on screen, and every other sheet waits behind it.
	private(set) var needsOnboarding = false

	func finishOnboarding() {
		Defaults[.firstRunFinished] = true
		needsOnboarding = false
	}

	// MARK: - visibleSheet

	/// One presenter shows all of them, so going from one to another is SwiftUI swapping a sheet, which it does reliably.
	/// Separate presenters would need one to finish going away before the next could appear.
	var visibleSheet: VisibleSheet? {
		get {
			if needsOnboarding {
				return .onboarding
			}
			if let presentedSheet {
				return .app(presentedSheet)
			}
			return switch selectedTab {
				case .board: boardSheet.map(VisibleSheet.board)
				case .logic: logicSheet.map(VisibleSheet.logic)
				case .library: librarySheet.map(VisibleSheet.library)
				case .ask: nil
			}
		}
		set {
			if newValue == nil, !needsOnboarding {
				dismissSheet()
			}
		}
	}

	/// What the one sheet presenter shows in the given layout. The wide layout shows settings beside the sidebar
	/// (`showsSettings`), with a tab's sheet waiting behind it, and the board's panels (`BoardSheet.isPanel`) in the inspector
	/// beside the board, so those are left out of the sheet there.
	func visibleSheet(isWide: Bool) -> VisibleSheet? {
		guard isWide, !needsOnboarding else {
			return visibleSheet
		}
		if showsSettings {
			return nil
		}
		guard presentedSheet == nil, selectedTab == .board else {
			return visibleSheet
		}
		return boardSheet.flatMap { $0.isPanel ? nil : .board($0) }
	}

	/// Settings is open. The wide layout shows it as the open item, not a sheet.
	var showsSettings: Bool {
		if case .settings? = presentedSheet {
			true
		} else {
			false
		}
	}

	/// The panel the wide layout's inspector shows beside the board, if any
	var boardPanel: BoardSheet? {
		boardSheet.flatMap { $0.isPanel ? $0 : nil }
	}

	/// The sheet presenter's binding for the given layout. A sheet going away because the layout changed (a panel moving
	/// into the inspector) has nothing on screen to dismiss, so it's ignored rather than closing the panel.
	func visibleSheetBinding(isWide: Bool) -> Binding<VisibleSheet?> {
		Binding(
			get: { [unowned self] in
				visibleSheet(isWide: isWide)
			},
			set: { [unowned self] newValue in
				if newValue == nil, !needsOnboarding, visibleSheet(isWide: isWide) != nil {
					dismissSheet()
				}
			}
		)
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

	// MARK: - openLibrary

	func openLibrary(_ route: LibraryRoute) {
		selectedTab = .library
		libraryPath.append(route)
	}

	// MARK: - presentSheet

	func presentSheet(_ sheet: AppSheet) {
		presentedSheet = sheet
	}

	func presentSheet(_ sheet: BoardSheet) {
		selectedTab = .board
		boardSheet = sheet
	}

	/// A panel's toolbar button: opens it, or closes it when it's already beside the board in the wide layout's inspector
	func toggle(_ sheet: BoardSheet) {
		if selectedTab == .board, presentedSheet == nil, boardSheet == sheet {
			boardSheet = nil
		} else {
			presentSheet(sheet)
		}
	}

	func presentSheet(_ sheet: LogicSheet) {
		selectedTab = .logic
		logicSheet = sheet
	}

	func presentSheet(_ sheet: LibrarySheet) {
		selectedTab = .library
		librarySheet = sheet
	}

	// MARK: - resumeBreakDown

	/// Opens the breakdown that was running when the app was closed. A restored sheet that is breaking down something
	/// picks it up itself, so it's left alone.
	func resumeBreakDown() {
		guard Defaults[.pendingBreakDown] != nil else { return }
		if case let .shared(item)? = presentedSheet, item.action == .breakDown {
			return
		}
		if case .breakDownSource? = boardSheet {
			selectedTab = .board
			return
		}
		presentSheet(.resumeBreakDown)
	}

	// MARK: - dismissSheet

	/// Closes the sheet on screen
	func dismissSheet() {
		if presentedSheet != nil {
			presentedSheet = nil
			return
		}
		switch selectedTab {
			case .board: boardSheet = nil
			case .logic: logicSheet = nil
			case .library: librarySheet = nil
			case .ask: break
		}
	}

	// MARK: - reveal

	/// Goes to a tab with nothing over it. Other tabs keep their sheets for when they're next opened.
	func reveal(_ tab: AppTab) {
		selectedTab = tab
		presentedSheet = nil
		switch tab {
			case .board: boardSheet = nil
			case .logic: logicSheet = nil
			case .library: librarySheet = nil
			case .ask: break
		}
	}

	// MARK: - openAnalysis

	/// Opens a board's analysis from anywhere, with that board behind it. A board that's gone just opens the tab.
	func openAnalysis(of board: Board.ID, in store: BoardStore) {
		reveal(.board)

		guard store.boards.contains(where: { $0.id == board }) else { return }
		store.open(board)
		presentSheet(.boardAnalysis(board, focus: nil))
	}

	// MARK: - openLibraryEntry

	func openLibraryEntry(category: LibraryContent, id: String) {
		// A sheet left open would hide the page, so the link would look like it did nothing
		reveal(.library)

		let route = LibraryRoute.detail(category: category, id: id)
		if libraryPath.last != route {
			libraryPath.append(route)
		}
	}

	// MARK: - reset()

	func reset(_ tab: AppTab) {
		switch tab {
			case .board, .ask:
				break
			case .logic:
				logicPath.removeAll()
			case .library:
				libraryPath.removeAll()
		}
	}

	// MARK: - startup()

	func startup() {
		needsOnboarding = !Defaults[.firstRunFinished]
		presentedSheet = Defaults[.presentedSheet]
		boardSheet = Defaults[.boardSheet]
		logicSheet = Defaults[.logicSheet]
		librarySheet = Defaults[.librarySheet]
		selectedTab = Defaults[.selectedTab]
		libraryPath = Defaults[.libraryPath]
		logicPath = Defaults[.logicPath]
	}
}
