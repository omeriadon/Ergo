//
//  CanvasView+Bar.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoSync
import SwiftUI

extension CanvasView {
	var barMode: CanvasBarMode {
		if isReadOnly {
			return switch activeSelection {
				case .statement: .viewOnly(.statement)
				case let .source(id): .viewOnly(.source(isLink: board.source(id)?.link != nil))
				case .link: .viewOnly(.link)
				case nil: .viewOnly(.nothing)
			}
		}
		if let activePick {
			return .picking(prompt(for: activePick))
		}
		return switch activeSelection {
			case .statement: .statement
			case .link: .link
			case let .source(id): .source(isLink: board.source(id)?.link != nil)
			case nil: .idle
		}
	}

	var barActions: CanvasBarActions {
		CanvasBarActions(
			add: addStatement,
			addText: { sourceSheet = .newText },
			addLink: { sourceSheet = .newLink },
			edit: {
				if case let .statement(id)? = activeSelection {
					edit(id)
				}
			},
			openSource: {
				if case let .source(id)? = activeSelection {
					open(id)
				}
			},
			breakDown: {
				if case let .source(id)? = activeSelection {
					navigation.presentSheet(.breakDownSource(id))
				}
			},
			delete: {
				switch activeSelection {
					case let .statement(id)?: delete(id)
					case let .link(id)?: deleteLink(id)
					case let .source(id)?: deleteSource(id)
					case nil: break
				}
			},
			cancelPick: { pick = nil },
			showAnnotations: {
				if let target = selectionTarget {
					navigation.presentSheet(.boardAnalysis(board.id, focus: target))
				}
			}
		)
	}

	// MARK: - Analysis

	/// What's still true of the board now, worked out each time
	var shownAnalysis: BoardAnalysisShown {
		analysis.shown(on: board)
	}

	var selectionTarget: BoardAnalysisTarget? {
		switch activeSelection {
			case let .statement(id)?: .statement(id)
			case let .link(id)?: .link(id)
			case let .source(id)?: .source(id)
			case nil: nil
		}
	}

	var selectionHasAnnotations: Bool {
		guard let target = selectionTarget else { return false }
		return shownAnalysis.current.contains { $0.target == target }
	}

	var isAnalysing: Bool {
		analysis.isRunning(board.id)
	}

	/// The first time, this starts a run. After that it opens what the last one found, which has the button to run again.
	func analyse() {
		let hasResults = analysis.statuses[board.id] != nil || analysis.written[board.id] != nil
		if !isAnalysing, !hasResults, sync.isSignedIn {
			analysis.start(board: board)
		}
		navigation.presentSheet(.boardAnalysis(board.id, focus: nil))
	}
}
