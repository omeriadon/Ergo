//
//  BoardsSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

struct BoardsSheet: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@Default(.logicLetters) var logicLetters

	@State private var breakingDown = false

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
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
							letters: letters,
							isCurrent: board.id == boardStore.current.id
						)
					}
					.buttonStyle(.plain)
					.swipeActions {
						Button("Delete", systemImage: "trash", role: .destructive) {
							boardStore.delete([board.id])
						}
					}
				}
			}
			.overlay {
				if boardStore.boards.isEmpty {
					ContentUnavailableView(
						"No Boards",
						systemImage: "doc.text",
						description: Text("Anything you write on the Check tab is kept here.")
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
}

private struct BoardRow: View {
	let board: LogicBoard
	let letters: [String]
	let isCurrent: Bool

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text(board.title(letters: letters))
					.font(.headline)
					.lineLimit(1)

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
