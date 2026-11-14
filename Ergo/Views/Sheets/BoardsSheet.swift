//
//  BoardsSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoLogic
import ErgoProtocol
import SwiftUI

struct BoardsSheet: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@State private var breakingDown = false

	@State private var renaming: Renaming<Board.ID>?

	/// A shared board waiting on the person to say so, since only its owner can undo it
	@State private var removing: Board?

	@State private var isShowingArchived = false

	private var list: some View {
		List {
			// Always there, since pulling a sheet's list down moves the sheet and never gets past the top
			if !boardStore.archivedBoards.isEmpty {
				ArchivedRow(count: boardStore.archivedBoards.count) {
					isShowingArchived = true
				}
			}

			ForEach(boardStore.listedBoards) { board in
				BoardListRow(
					board: board,
					rename: { renaming = Renaming(id: board.id, name: board.name) },
					removing: $removing
				)
			}
		}
	}

	var body: some View {
		NavigationStack {
			list
				.renameAlert("Rename Board", renaming: $renaming) { id, name in
					boardStore.rename(id, to: name)
				}
				.boardRemovalDialog($removing)
				.navigationDestination(isPresented: $isShowingArchived) {
					ArchivedBoardsView()
				}
				.overlay {
					if boardStore.boards.isEmpty {
						ContentUnavailableView(
							"No Boards",
							systemImage: "doc.text",
							description: Text("Anything you write on the Board tab is kept here.")
						)
					}
				}
				.toolbarTitleVire("Boards", "text.page.and.line.vertical.and.text.page")
				.toolbar {
					ToolbarItem(placement: .sheetDismissal) {
						Button(role: .close) {
							navigation.dismissSheet()
						}
					}

					ToolbarItem(placement: .topBarTrailing) {
						NewBoardMenu { template in
							boardStore.newBoard(from: template)
							navigation.dismissSheet()
						} extra: {
							Divider()

							Button("Break Down", systemImage: "list.bullet.indent") {
								breakingDown = true
							}
							.accessibilityIdentifier("boards.newBoard.breakDown")
						}
						.buttonStyle(.glassProminent)
						.scrollEdgeEffectStyle(.soft, for: .all)
						.accessibilityIdentifier("boards.newBoard")
					}
				}
				.sheet(isPresented: $breakingDown) {
					BreakDownSheet()
				}
		}
	}
}

/// What's been archived. Opening one puts it on the canvas like any other, and it stays archived until it's brought back.
private struct ArchivedBoardsView: View {
	@Environment(BoardStore.self)
	private var boardStore

	@State private var removing: Board?

	var body: some View {
		List {
			ForEach(boardStore.archivedBoards) { board in
				BoardListRow(board: board, removing: $removing)
			}
		}
		.boardRemovalDialog($removing)
		.overlay {
			if boardStore.archivedBoards.isEmpty {
				ContentUnavailableView("No Archived Boards", systemImage: "archivebox")
			}
		}
		.navigationTitle("Archived")
		.toolbarTitleDisplayMode(.inline)
	}
}

/// A board in a list, with its swipes and context menu
private struct BoardListRow: View {
	let board: Board

	/// Archived boards aren't renamed
	var rename: (() -> Void)?

	@Binding var removing: Board?

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	var body: some View {
		Button {
			boardStore.open(board.id)
			navigation.dismissSheet()
		} label: {
			BoardRow(
				board: board,
				isCurrent: board.id == boardStore.current.id,
				share: boardStore.shares[board.id],
				isPinned: boardStore.pinnedIDs.contains(board.id)
			)
		}
		.buttonStyle(.plain)
		.swipeActions {
			removeAction

			ArchiveButton(isArchived: boardStore.archivedIDs.contains(board.id)) {
				boardStore.setArchived(!boardStore.archivedIDs.contains(board.id), board.id)
			}
		}
		.swipeActions(edge: .leading) {
			renameButton

			if !boardStore.archivedIDs.contains(board.id) {
				PinButton(isPinned: boardStore.pinnedIDs.contains(board.id)) {
					boardStore.setPinned(!boardStore.pinnedIDs.contains(board.id), board.id)
				}
			}
		}
		.contextMenu {
			renameButton

			BoardActions(board: board) {
				if boardStore.shares[board.id] == nil {
					boardStore.delete([board.id])
				} else {
					removing = board
				}
			}
		}
	}

	/// Not offered on a board this person can only read
	@ViewBuilder
	private var renameButton: some View {
		if let rename, boardStore.canEdit(board.id) {
			Button("Rename", systemImage: "pencil", action: rename)
				.tint(.orange)
		}
	}

	/// A tombstone means something different depending on whose board it is: deleted, left, or deleted for everyone
	@ViewBuilder
	private var removeAction: some View {
		switch boardStore.shares[board.id]?.role {
			case nil:
				Button("Delete", systemImage: "trash", role: .destructive) {
					boardStore.delete([board.id])
				}
			case .owner:
				// No destructive role, since that would look like it had gone before the confirmation
				Button("Delete", systemImage: "trash") {
					removing = board
				}
				.tint(.red)
			case .editor, .viewer:
				// No destructive role, for the same reason
				Button("Leave", systemImage: "rectangle.portrait.and.arrow.right") {
					removing = board
				}
				.tint(.red)
		}
	}
}

/// Pin, archive and removing a board, for the canvas's menu and a board's context menu
struct BoardActions: View {
	let board: Board
	let remove: () -> Void

	@Environment(BoardStore.self)
	private var boardStore

	private var leaves: Bool {
		guard let role = boardStore.shares[board.id]?.role else { return false }
		return role != .owner
	}

	var body: some View {
		Section {
			// An archived board isn't in the list for a pin to do anything
			if !boardStore.archivedIDs.contains(board.id) {
				PinButton(isPinned: boardStore.pinnedIDs.contains(board.id)) {
					boardStore.setPinned(!boardStore.pinnedIDs.contains(board.id), board.id)
				}
				.accessibilityIdentifier("board.pin")
			}

			ArchiveButton(isArchived: boardStore.archivedIDs.contains(board.id)) {
				boardStore.setArchived(!boardStore.archivedIDs.contains(board.id), board.id)
			}
			.accessibilityIdentifier("board.archive")
		}

		Section {
			Button(leaves ? "Leave" : "Delete", systemImage: leaves ? "rectangle.portrait.and.arrow.right" : "trash", role: .destructive, action: remove)
				.accessibilityIdentifier("board.remove")
		}
	}
}

extension View {
	/// Asks before a board goes, in the words for whose board it is
	func boardRemovalDialog(_ board: Binding<Board?>) -> some View {
		modifier(BoardRemovalDialog(board: board))
	}
}

private struct BoardRemovalDialog: ViewModifier {
	@Binding var board: Board?

	@Environment(BoardStore.self)
	private var boardStore

	private var isShown: Binding<Bool> {
		Binding(
			get: { board != nil },
			set: { isShown in
				if !isShown {
					board = nil
				}
			}
		)
	}

	private var wording: (title: String, button: String, message: String, identifier: String) {
		switch board.flatMap({ boardStore.shares[$0.id]?.role }) {
			case nil:
				("Delete this board?", "Delete", "This can't be undone", "boards.delete")
			case .owner:
				("Delete for everyone?", "Delete for Everyone", "This board is shared, so it goes for everyone on it", "boards.deleteForEveryone")
			case .editor, .viewer:
				("Leave this board?", "Leave", "Only its owner can invite you back", "boards.leave")
		}
	}

	func body(content: Content) -> some View {
		content
			.confirmationDialog(wording.title, isPresented: isShown, titleVisibility: .visible, presenting: board) { board in
				Button(wording.button, role: .destructive) {
					boardStore.delete([board.id])
				}
				.accessibilityIdentifier(wording.identifier)
			} message: { _ in
				Text(wording.message)
			}
	}
}

struct BoardRow: View {
	let board: Board
	let isCurrent: Bool
	var share: BoardShare?
	var isPinned = false

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text(board.title)
					.font(.headline)
					.lineLimit(1)

				if let share {
					Text(share.summary)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}

				Text(board.modified, format: .relative(presentation: .named))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)

			if isPinned {
				Image(systemName: "pin.fill")
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityLabel("Pinned")
			}

			if isCurrent {
				Image(systemName: "checkmark")
					.foregroundStyle(.tint)
					.accessibilityLabel("Open")
			}
		}
		.contentShape(Rectangle())
	}
}
