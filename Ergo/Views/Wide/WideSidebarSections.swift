//
//  WideSidebarSections.swift
//  Ergo
//

import Defaults
import ErgoLogic
import ErgoProtocol
import SwiftUI

// Rows here are the lists' own rows without their buttons, since a button in a selectable list takes the tap from
// selecting. Each is tagged with what selecting it opens.

// MARK: - Boards

struct WideSidebarBoards: View {
	@Binding var renaming: Renaming<SidebarItem>?
	@Binding var removing: Board?

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@State private var isExpanded = true

	var body: some View {
		Section(isExpanded: $isExpanded) {
			ForEach(boardStore.listedBoards) { board in
				WideSidebarBoardRow(board: board, renaming: $renaming, removing: $removing)
			}
		} header: {
			WideSidebarHeader("Boards") {
				// Blank only: Break Down closes itself through the boards sheet, which a sheet from here isn't
				Button("New Board", systemImage: "square.and.pencil") {
					navigation.newBoard(in: boardStore)
				}
				.accessibilityIdentifier("sidebar.newBoard")
			}
		}
	}
}

private struct WideSidebarBoardRow: View {
	let board: Board

	@Binding var renaming: Renaming<SidebarItem>?
	@Binding var removing: Board?

	@Environment(BoardStore.self)
	private var boardStore

	var body: some View {
		BoardRow(
			board: board,
			isCurrent: false,
			share: boardStore.shares[board.id],
			isPinned: boardStore.pinnedIDs.contains(board.id)
		)
		.tag(SidebarItem.board(board.id) as SidebarItem?)
		.contextMenu {
			// Not offered on a board this person can only read
			if boardStore.canEdit(board.id) {
				Button("Rename", systemImage: "pencil") {
					renaming = Renaming(id: SidebarItem.board(board.id), name: board.name)
				}
			}

			BoardActions(board: board) {
				if boardStore.shares[board.id] == nil {
					boardStore.delete([board.id])
				} else {
					removing = board
				}
			}
		}
	}
}

// MARK: - Logic

struct WideSidebarLogic: View {
	@Binding var renaming: Renaming<SidebarItem>?

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(ScratchpadStore.self)
	private var scratchpadStore

	@Default(.logicLetters) private var logicLetters

	@State private var isExpanded = true

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	var body: some View {
		Section(isExpanded: $isExpanded) {
			LogicCourseRow()
				.tag(SidebarItem.course as SidebarItem?)

			ForEach(scratchpadStore.sortedScratchpads) { scratchpad in
				ScratchpadRow(scratchpad: scratchpad, letters: letters)
					.tag(SidebarItem.scratchpad(scratchpad.id) as SidebarItem?)
					.contextMenu {
						Button("Rename", systemImage: "pencil") {
							renaming = Renaming(id: SidebarItem.scratchpad(scratchpad.id), name: scratchpad.name)
						}

						Button("Delete", systemImage: "trash", role: .destructive) {
							scratchpadStore.delete([scratchpad.id])
						}
					}
			}
		} header: {
			WideSidebarHeader("Logic") {
				Button("New Scratchpad", systemImage: "square.and.pencil") {
					navigation.newScratchpad(in: scratchpadStore)
				}
				.accessibilityIdentifier("sidebar.newScratchpad")
			}
		}
	}
}

// MARK: - Ask

struct WideSidebarAsk: View {
	@Binding var renaming: Renaming<SidebarItem>?
	@Binding var attachmentsOf: AskConversation?

	@Environment(AskStore.self)
	private var askStore

	@Environment(TranslationAccount.self)
	private var account

	@State private var isExpanded = true

	var body: some View {
		Section(isExpanded: $isExpanded) {
			if account.isSignedInHere {
				ForEach(askStore.listedConversations) { conversation in
					WideSidebarChatRow(conversation: conversation, renaming: $renaming, attachmentsOf: $attachmentsOf)
				}
			} else {
				// Its detail is the sign-in prompt
				Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
					.tag(SidebarItem.ask as SidebarItem?)
			}
		} header: {
			WideSidebarHeader("Ask") {
				if account.isSignedInHere {
					WideSidebarNewChatButton()
				}
			}
		}
	}
}

private struct WideSidebarChatRow: View {
	let conversation: AskConversation

	@Binding var renaming: Renaming<SidebarItem>?
	@Binding var attachmentsOf: AskConversation?

	@Environment(AskStore.self)
	private var askStore

	var body: some View {
		AskHistoryRow(conversation: conversation, isAnswering: askStore.runs[conversation.id] != nil)
			.tag(SidebarItem.chat(conversation.id) as SidebarItem?)
			.contextMenu {
				Button("Rename", systemImage: "pencil") {
					renaming = Renaming(id: SidebarItem.chat(conversation.id), name: conversation.name)
				}

				AskChatActions(
					conversation: conversation,
					showAttachments: { attachmentsOf = conversation },
					delete: { askStore.delete(conversation.id) }
				)
			}
	}
}

/// `AskNewChatButton`, but it goes to the Ask section too, since the sidebar can start one from any section
private struct WideSidebarNewChatButton: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(AskStore.self)
	private var askStore

	var body: some View {
		Menu {
			ForEach(AskMode.allCases, id: \.self) { mode in
				Button(mode.name, systemImage: mode.symbol) {
					navigation.newChat(mode: mode, in: askStore)
				}
			}
		} label: {
			Label("New Chat", systemImage: "square.and.pencil")
		} primaryAction: {
			navigation.newChat(in: askStore)
		}
		.accessibilityIdentifier("sidebar.newChat")
	}
}

// MARK: - Library

struct WideSidebarLibrary: View {
	@State private var isExpanded = true

	var body: some View {
		Section("Library", isExpanded: $isExpanded) {
			Label("Library", systemImage: "books.vertical")
				.tag(SidebarItem.libraryHome as SidebarItem?)

			// In the grid's order
			ForEach(LibraryContent.allCases, id: \.self) { category in
				Label(category.title, systemImage: category.symbol)
					.tag(SidebarItem.library(category) as SidebarItem?)
			}

			Label("Bookmarks", systemImage: "bookmark")
				.tag(SidebarItem.bookmarks as SidebarItem?)
		}
	}
}
