//
//  BoardsSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import SwiftUI

struct BoardsSheet: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@State private var breakingDown = false

	/// A board this person owns and has shared, whose delete goes for everyone
	@State private var deletingShared: Board?

	private var isConfirmingDelete: Binding<Bool> {
		Binding(
			get: { deletingShared != nil },
			set: { isShown in
				if !isShown {
					deletingShared = nil
				}
			}
		)
	}

	/// A board someone else shared. Only its owner can invite this person back, so a stray swipe mustn't be enough.
	@State private var leaving: Board?

	private var isConfirmingLeave: Binding<Bool> {
		Binding(
			get: { leaving != nil },
			set: { isShown in
				if !isShown {
					leaving = nil
				}
			}
		)
	}

	var body: some View {
		NavigationStack {
			List {
				ForEach(boardStore.sortedBoards) { board in
					Button {
						boardStore.open(board.id)
						navigation.dismissSheet()
					} label: {
						BoardRow(
							board: board,
							isCurrent: board.id == boardStore.current.id,
							share: boardStore.shares[board.id]
						)
					}
					.buttonStyle(.plain)
					.swipeActions {
						removeAction(for: board)
					}
				}
			}
			.confirmationDialog("Delete for everyone?", isPresented: isConfirmingDelete, titleVisibility: .visible, presenting: deletingShared) { board in
				Button("Delete for Everyone", role: .destructive) {
					boardStore.delete([board.id])
				}
				.accessibilityIdentifier("boards.deleteForEveryone")
			} message: { _ in
				Text("This board is shared, so it goes for everyone on it")
			}
			.confirmationDialog("Leave this board?", isPresented: isConfirmingLeave, titleVisibility: .visible, presenting: leaving) { board in
				Button("Leave", role: .destructive) {
					boardStore.delete([board.id])
				}
				.accessibilityIdentifier("boards.leave")
			} message: { _ in
				Text("Only its owner can invite you back")
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
				ToolbarItem(placement: .topBarLeading) {
					Button(role: .close) {
						navigation.dismissSheet()
					}
				}

				ToolbarItem(placement: .topBarTrailing) {
					Menu("New Board", systemImage: "square.and.pencil") {
						Button("Blank", systemImage: "square.dashed") {
							boardStore.newBoard()
							navigation.dismissSheet()
						}
						.accessibilityIdentifier("boards.newBoard.blank")

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

	/// A tombstone means something different depending on whose board it is: deleted, left, or deleted for everyone
	@ViewBuilder
	private func removeAction(for board: Board) -> some View {
		switch boardStore.shares[board.id]?.role {
			case nil:
				Button("Delete", systemImage: "trash", role: .destructive) {
					boardStore.delete([board.id])
				}
			case .owner:
				// No destructive role, since that would look like it had gone before the confirmation
				Button("Delete", systemImage: "trash") {
					deletingShared = board
				}
				.tint(.red)
			case .editor, .viewer:
				// No destructive role, for the same reason
				Button("Leave", systemImage: "rectangle.portrait.and.arrow.right") {
					leaving = board
				}
				.tint(.red)
		}
	}
}

struct BoardRow: View {
	let board: Board
	let isCurrent: Bool
	var share: BoardShare?

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

			if isCurrent {
				Image(systemName: "checkmark")
					.foregroundStyle(.tint)
					.accessibilityLabel("Open")
			}
		}
		.contentShape(Rectangle())
	}
}
