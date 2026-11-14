//
//  NewBoardMenu.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import ErgoLogic
import SwiftUI

/// New Board, wherever a board is made: a tap makes a blank one, and the menu offers the templates (`BoardTemplate`),
/// then anything the place adds after them.
struct NewBoardMenu<Extra: View>: View {
	let make: (BoardTemplate) -> Void
	@ViewBuilder let extra: Extra

	var body: some View {
		Menu {
			ForEach(BoardTemplate.allCases) { template in
				Button(template.title, systemImage: template.systemImage) {
					make(template)
				}
				.accessibilityIdentifier(template.accessibilityIdentifier)
			}

			extra
		} label: {
			Label("New Board", systemImage: "square.and.pencil")
		} primaryAction: {
			make(.blank)
		}
	}
}

private extension BoardTemplate {
	var systemImage: String {
		switch self {
			case .blank: "square.dashed"
			case .claimAndReasons: "arrow.down.to.line"
			case .objectionAndReply: "arrow.left.arrow.right"
			case .prosAndCons: "plusminus"
			case .toulmin: "square.grid.3x1.below.line.grid.1x2"
		}
	}

	/// Blank's is `boards.newBoard.blank`, as it was before there were templates
	var accessibilityIdentifier: String {
		"boards.newBoard.\(rawValue)"
	}
}
