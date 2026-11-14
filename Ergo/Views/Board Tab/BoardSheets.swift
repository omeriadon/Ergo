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

	/// Pasted text broken down into a new board, from the wide layout's sidebar
	case breakDown
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

	/// Sits beside the board rather than being a task of its own. The wide layout shows these in the inspector, not a sheet.
	var isPanel: Bool {
		switch self {
			case .boardAnalysis, .quickAI, .boardPeople:
				true

			case .boards, .breakDown, .breakDownSource, .resumeBreakDown:
				false
		}
	}
}

struct BoardSheetContent: View {
	let sheet: BoardSheet

	var body: some View {
		switch sheet {
			case .boards:
				BoardsSheet()

			case .breakDown:
				BreakDownSheet()

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
