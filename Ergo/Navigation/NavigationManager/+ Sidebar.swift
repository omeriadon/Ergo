//
//  + Sidebar.swift
//  Ergo
//

import ErgoLogic
import ErgoProtocol
import SwiftUI

/// What the wide layout's sidebar can select. It's never stored: it's read from the same state the tabs use, and selecting
/// one writes that state, so the narrow and wide layouts always show the same thing.
enum SidebarItem: Hashable {
	case board(Board.ID)
	case course
	case scratchpad(LogicScratchpad.ID)

	/// The Ask tab itself, which is its sign-in prompt when there's no account here
	case ask
	case chat(AskConversation.ID)

	/// The library's grid
	case libraryHome
	case library(LibraryContent)
	case bookmarks
	case practice

	/// Settings, which the wide layout shows as the open item rather than a sheet
	case settings
}

extension NavigationManager {
	// MARK: - sidebarSelection

	/// What the sidebar shows as selected, worked out from what's open, so it follows intents, links and the narrow layout
	func sidebarSelection(
		boards: BoardStore,
		scratchpads: ScratchpadStore,
		ask: AskStore,
		isSignedIn: Bool
	) -> SidebarItem? {
		if showsSettings {
			return .settings
		}
		return switch selectedTab {
			case .board:
				.board(boards.current.id)
			case .logic:
				logicSidebarItem(scratchpads: scratchpads)
			case .ask:
				isSignedIn && ask.isChatOpen ? .chat(ask.current.id) : .ask
			case .library:
				librarySidebarItem
		}
	}

	private func logicSidebarItem(scratchpads: ScratchpadStore) -> SidebarItem? {
		switch logicPath.first {
			case .scratchpad:
				.scratchpad(scratchpads.current.id)
			case .course, .lesson:
				.course
			case nil:
				nil
		}
	}

	/// The first route is where the person went from the grid, so a page opened from a list keeps that list selected
	private var librarySidebarItem: SidebarItem {
		guard let first = libraryPath.first else { return .libraryHome }
		switch first {
			case .bookmarks:
				return .bookmarks
			case .practice:
				return .practice
			case let .detail(category, _):
				return .library(category)
			default:
				return first.listCategory.map(SidebarItem.library) ?? .libraryHome
		}
	}

	// MARK: - select

	/// Opens what was picked in the sidebar the same way its tab would. Picking what's already selected leaves it alone,
	/// so a lesson or a library page isn't thrown away.
	func select(
		_ item: SidebarItem,
		boards: BoardStore,
		scratchpads: ScratchpadStore,
		ask: AskStore,
		isSignedIn: Bool
	) {
		guard item != sidebarSelection(boards: boards, scratchpads: scratchpads, ask: ask, isSignedIn: isSignedIn) else { return }

		// Anything else picked replaces settings, which isn't a sheet here
		if showsSettings {
			presentedSheet = nil
		}

		switch item {
			case let .board(id):
				openBoard(id, in: boards)
			case .course:
				selectedTab = .logic
				logicPath = [.course]
			case let .scratchpad(id):
				openScratchpad(id, in: scratchpads)
			case .ask:
				selectedTab = .ask
			case let .chat(id):
				selectedTab = .ask
				ask.open(id)
			case .libraryHome:
				selectedTab = .library
				libraryPath.removeAll()
			case let .library(category):
				selectedTab = .library
				libraryPath = [.category(category)]
			case .bookmarks:
				selectedTab = .library
				libraryPath = [.bookmarks]
			case .practice:
				selectedTab = .library
				libraryPath = [.practice]
			case .settings:
				presentSheet(.settings(id: "3refd"))
		}
	}

	// MARK: - Opening

	/// A sheet or panel over the board that was open is about that board, so switching to another closes it
	func openBoard(_ id: Board.ID, in boards: BoardStore) {
		guard id != boards.current.id else {
			selectedTab = .board
			return
		}
		reveal(.board)
		boards.open(id)
	}

	func newBoard(_ template: BoardTemplate = .blank, in boards: BoardStore) {
		reveal(.board)
		boards.newBoard(from: template)
	}

	func openScratchpad(_ id: LogicScratchpad.ID, in scratchpads: ScratchpadStore) {
		selectedTab = .logic
		scratchpads.open(id)
		logicPath = [.scratchpad]
	}

	func newScratchpad(in scratchpads: ScratchpadStore) {
		selectedTab = .logic
		scratchpads.newScratchpad()
		logicPath = [.scratchpad]
	}

	func newChat(mode: AskMode = .normal, in ask: AskStore) {
		selectedTab = .ask
		ask.newConversation(mode: mode)
	}
}
