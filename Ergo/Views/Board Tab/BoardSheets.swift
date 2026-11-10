//
//  BoardSheets.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
import ErgoSync
import SwiftUI

/// The sheets that belong to the Board tab. See `NavigationManager.boardSheet`.
nonisolated enum BoardSheet: Hashable, Identifiable, Codable, Defaults.Serializable {
	case boards
	case breakDownSource(BoardSource.ID)

	/// The breakdown that was running when the app was closed, found again from `Defaults[.pendingBreakDown]`
	case resumeBreakDown
	case boardPeople(Board.ID)

	/// What a board's analysis found, all of it or just what's about one thing
	case boardAnalysis(Board.ID, focus: BoardAnalysisTarget?)

	/// A chat about the board, beside it
	case quickAI(Board.ID)

	var id: Self {
		self
	}
}

struct BoardSheetContent: View {
	let sheet: BoardSheet

	var body: some View {
		switch sheet {
			case .boards:
				BoardsSheet()

			case let .breakDownSource(id):
				SourceBreakDownSheet(id: id)

			case .resumeBreakDown:
				ResumedBreakDownSheet()

			case let .boardPeople(board):
				BoardPeopleSheet(board: board)

			case let .boardAnalysis(board, focus):
				BoardAnalysisSheet(board: board, focus: focus)

			case let .quickAI(board):
				QuickAISheet(board: board)
		}
	}
}
