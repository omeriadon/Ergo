//
//  NavigationManagerTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
@testable import Ergo
import ErgoShare
import Foundation
import Testing

/// Which sheet is on screen. A tab's sheet only shows while that tab is selected, and an app sheet shows over any tab.
@Suite(.cleanDefaults)
struct NavigationManagerSheetTests {
	// MARK: - Starting

	@Test func itStartsOnTheBoardTabWithNothingOverIt() {
		let navigation = NavigationManager()

		#expect(navigation.selectedTab == .board)
		#expect(navigation.visibleSheet == nil)
	}

	// MARK: - A tab's own sheet

	@Test func presentingATabsSheetGoesToThatTabAndShowsIt() {
		let navigation = NavigationManager()

		navigation.presentSheet(LogicSheet.logicLetters)

		#expect(navigation.selectedTab == .logic)
		#expect(navigation.visibleSheet == .logic(.logicLetters))
	}

	@Test func eachTabsSheetIsPresentedOnItsOwnTab() {
		let navigation = NavigationManager()

		navigation.presentSheet(BoardSheet.boards)
		#expect(navigation.selectedTab == .board)
		#expect(navigation.visibleSheet == .board(.boards))

		navigation.presentSheet(LibrarySheet.addEntryToChat(.text("Entry")))
		#expect(navigation.selectedTab == .library)
		#expect(navigation.visibleSheet == .library(.addEntryToChat(.text("Entry"))))
	}

	@Test func leavingATabHidesItsSheetAndComingBackRestoresIt() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)

		navigation.selectedTab = .logic
		#expect(navigation.visibleSheet == nil)

		navigation.selectedTab = .board
		#expect(navigation.visibleSheet == .board(.boards))
	}

	@Test func eachTabKeepsItsOwnSheetWhileAnotherShows() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)
		navigation.presentSheet(LogicSheet.logicLetters)

		navigation.selectedTab = .board
		#expect(navigation.visibleSheet == .board(.boards))

		navigation.selectedTab = .logic
		#expect(navigation.visibleSheet == .logic(.logicLetters))
	}

	@Test func theAskTabShowsNoTabSheet() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)
		navigation.presentSheet(LogicSheet.logicLetters)

		navigation.selectedTab = .ask

		#expect(navigation.visibleSheet == nil)
	}

	@Test func aNewSheetOnATabReplacesItsOldOne() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)

		navigation.presentSheet(BoardSheet.resumeBreakDown)

		#expect(navigation.visibleSheet == .board(.resumeBreakDown))
	}

	// MARK: - App sheets

	@Test func anAppSheetShowsOverAnyTab() {
		let navigation = NavigationManager()
		navigation.presentSheet(AppSheet.plus)

		for tab in [AppTab.board, .logic, .ask, .library] {
			navigation.selectedTab = tab
			#expect(navigation.visibleSheet == .app(.plus))
		}
	}

	@Test func anAppSheetShowsOverATabsSheet() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)

		navigation.presentSheet(AppSheet.settings(id: "main"))

		#expect(navigation.visibleSheet == .app(.settings(id: "main")))
		#expect(navigation.boardSheet == .boards)
	}

	// MARK: - Dismissing

	@Test func dismissingTakesOffTheAppSheetFirstThenTheTabs() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)
		navigation.presentSheet(AppSheet.plus)

		navigation.dismissSheet()
		#expect(navigation.visibleSheet == .board(.boards))

		navigation.dismissSheet()
		#expect(navigation.visibleSheet == nil)
	}

	@Test func dismissingOnlyClosesTheSheetOnScreen() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)
		navigation.presentSheet(LogicSheet.logicLetters)

		navigation.dismissSheet()

		#expect(navigation.logicSheet == nil)
		#expect(navigation.boardSheet == .boards)
	}

	@Test func dismissingWithNothingOverTheTabDoesNothing() {
		let navigation = NavigationManager()

		navigation.dismissSheet()
		navigation.selectedTab = .ask
		navigation.dismissSheet()

		#expect(navigation.visibleSheet == nil)
	}

	/// SwiftUI sets the binding to nil when a sheet is swiped away
	@Test func settingTheVisibleSheetToNilDismissesIt() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)

		navigation.visibleSheet = nil

		#expect(navigation.boardSheet == nil)
	}

	@Test func settingTheVisibleSheetToASheetDoesNothing() {
		let navigation = NavigationManager()

		navigation.visibleSheet = .board(.boards)

		#expect(navigation.visibleSheet == nil)
	}

	// MARK: - Revealing

	@Test func revealingATabClearsWhatIsOverIt() {
		let navigation = NavigationManager()
		navigation.presentSheet(LogicSheet.logicLetters)
		navigation.presentSheet(AppSheet.plus)
		navigation.selectedTab = .board

		navigation.reveal(.logic)

		#expect(navigation.selectedTab == .logic)
		#expect(navigation.presentedSheet == nil)
		#expect(navigation.logicSheet == nil)
		#expect(navigation.visibleSheet == nil)
	}

	@Test func revealingATabLeavesTheOtherTabsSheetsForLater() {
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.boards)
		navigation.presentSheet(LibrarySheet.addEntryToChat(.text("Entry")))

		navigation.reveal(.logic)

		#expect(navigation.boardSheet == .boards)
		#expect(navigation.librarySheet == .addEntryToChat(.text("Entry")))
	}

	@Test func revealingTheAskTabStillClearsAnAppSheet() {
		let navigation = NavigationManager()
		navigation.presentSheet(AppSheet.plus)

		navigation.reveal(.ask)

		#expect(navigation.selectedTab == .ask)
		#expect(navigation.presentedSheet == nil)
	}

	// MARK: - Remembered for the next launch

	@Test func sheetsAndTabAreSavedAsTheyChange() {
		let navigation = NavigationManager()

		navigation.presentSheet(LogicSheet.logicLetters)
		navigation.presentSheet(AppSheet.plus)

		#expect(Defaults[.selectedTab] == .logic)
		#expect(Defaults[.logicSheet] == .logicLetters)
		#expect(Defaults[.presentedSheet] == .plus)
	}

	@Test func startingUpBringsBackWhatWasOnScreen() {
		Defaults[.selectedTab] = .library
		Defaults[.librarySheet] = .addEntryToChat(.text("Entry"))
		Defaults[.boardSheet] = .boards
		Defaults[.libraryPath] = [.bookmarks]
		let navigation = NavigationManager()

		navigation.startup()

		#expect(navigation.selectedTab == .library)
		#expect(navigation.visibleSheet == .library(.addEntryToChat(.text("Entry"))))
		#expect(navigation.boardSheet == .boards)
		#expect(navigation.libraryPath == [.bookmarks])
	}
}

/// Going to a page of the library, and opening the board's analysis
@Suite(.cleanDefaults)
struct NavigationManagerRoutingTests {
	@Test func openingALibraryEntryGoesThereAndClearsASheetThatWouldHideIt() {
		let navigation = NavigationManager()
		navigation.presentSheet(LibrarySheet.addEntryToChat(.text("Entry")))
		navigation.presentSheet(AppSheet.plus)

		navigation.openLibraryEntry(category: .fallacies, id: "straw-man")

		#expect(navigation.selectedTab == .library)
		#expect(navigation.libraryPath == [.detail(category: .fallacies, id: "straw-man")])
		#expect(navigation.visibleSheet == nil)
	}

	@Test func openingTheSameEntryAgainDoesNotStackIt() {
		let navigation = NavigationManager()

		navigation.openLibraryEntry(category: .fallacies, id: "straw-man")
		navigation.openLibraryEntry(category: .fallacies, id: "straw-man")

		#expect(navigation.libraryPath.count == 1)
	}

	@Test func openingADifferentEntryPushesOnTop() {
		let navigation = NavigationManager()

		navigation.openLibraryEntry(category: .fallacies, id: "straw-man")
		navigation.openLibraryEntry(category: .biases, id: "anchoring")

		#expect(navigation.libraryPath.count == 2)
		#expect(navigation.currentLibraryCategory == .biases)
	}

	@Test func showingAListOpensItOnceOnTopOfWhereYouAre() {
		let navigation = NavigationManager()
		navigation.openLibraryEntry(category: .fallacies, id: "straw-man")

		navigation.showLibraryList(.biases)
		navigation.showLibraryList(.biases)

		#expect(navigation.libraryPath.count == 2)
		#expect(navigation.libraryPath.last == .category(.biases))
	}

	@Test func theLibraryPathIsSaved() {
		let navigation = NavigationManager()

		navigation.openLibrary(.bookmarks)

		#expect(Defaults[.libraryPath] == [.bookmarks])
	}

	@Test func resettingATabEmptiesItsPathAndLeavesTheOthers() {
		let navigation = NavigationManager()
		navigation.openLibrary(.bookmarks)
		navigation.logicPath = [.course]

		navigation.reset(.logic)
		#expect(navigation.logicPath.isEmpty)
		#expect(navigation.libraryPath == [.bookmarks])

		navigation.reset(.library)
		#expect(navigation.libraryPath.isEmpty)
	}

	// MARK: - Analysis

	@Test func openingAnAnalysisOpensThatBoardWithTheSheetOver() {
		let first = Board([card("First")])
		let second = Board([card("Second")])
		let boards = BoardStore.test(first, second)
		let navigation = NavigationManager()
		navigation.selectedTab = .ask

		navigation.openAnalysis(of: second.id, in: boards)

		#expect(navigation.selectedTab == .board)
		#expect(boards.currentID == second.id)
		#expect(navigation.visibleSheet == .board(.boardAnalysis(second.id, focus: nil)))
	}

	@Test func anAnalysisOfABoardThatIsGoneJustOpensTheTab() {
		let boards = BoardStore.test(Board([card("Only")]))
		let navigation = NavigationManager()
		navigation.selectedTab = .ask

		navigation.openAnalysis(of: UUID(), in: boards)

		#expect(navigation.selectedTab == .board)
		#expect(navigation.visibleSheet == nil)
	}

	// MARK: - A breakdown still running

	@Test func nothingPendingOpensNoBreakdown() {
		let navigation = NavigationManager()

		navigation.resumeBreakDown()

		#expect(navigation.visibleSheet == nil)
	}

	@Test func aPendingBreakdownOpensOnTheBoardTab() {
		Defaults[.pendingBreakDown] = PendingBreakDown(request: .test("Text"))
		let navigation = NavigationManager()
		navigation.selectedTab = .logic

		navigation.resumeBreakDown()

		#expect(navigation.selectedTab == .board)
		#expect(navigation.visibleSheet == .board(.resumeBreakDown))
	}

	/// A restored sheet that is already breaking something down picks it up itself
	@Test func aRestoredBreakdownSheetIsLeftAlone() {
		Defaults[.pendingBreakDown] = PendingBreakDown(request: .test("Text"))
		let navigation = NavigationManager()
		navigation.presentSheet(AppSheet.shared(SharedItem(content: .text("Text"), action: .breakDown)))

		navigation.resumeBreakDown()

		#expect(navigation.boardSheet == nil)
	}

	@Test func aBreakdownOfASourceIsLeftOpenAndItsTabSelected() {
		Defaults[.pendingBreakDown] = PendingBreakDown(request: .test("Text"))
		let navigation = NavigationManager()
		navigation.presentSheet(BoardSheet.breakDownSource(UUID()))
		navigation.selectedTab = .logic

		navigation.resumeBreakDown()

		#expect(navigation.selectedTab == .board)
		guard case .breakDownSource? = navigation.boardSheet else {
			Issue.record("Expected the source's breakdown sheet to stay, found \(String(describing: navigation.boardSheet))")
			return
		}
	}
}
