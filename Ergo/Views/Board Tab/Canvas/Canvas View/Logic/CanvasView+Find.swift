//
//  CanvasView+Find.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ErgoLogic
import SwiftUI

/// A card or source that has what's being looked for
struct CanvasFindMatch {
	let selection: CanvasSelection
	let position: CanvasPoint
}

extension CanvasView {
	/// Top to bottom and then left to right, the way a board reads
	var findMatches: [CanvasFindMatch] {
		guard let query = find?.query, !query.isEmpty else { return [] }

		let statements = board.statements
			.filter { $0.english.matchesFind(query) }
			.map { CanvasFindMatch(selection: .statement($0.id), position: $0.position) }
		let sources = board.sources
			.filter { $0.content.findText.matchesFind(query) }
			.map { CanvasFindMatch(selection: .source($0.id), position: $0.position) }

		return (statements + sources).sorted {
			($0.position.y, $0.position.x) < ($1.position.y, $1.position.x)
		}
	}

	var currentFindMatch: CanvasFindMatch? {
		find?.current(in: findMatches)
	}

	@ViewBuilder
	var findBar: some View {
		if find != nil {
			FindBar(find: $find, prompt: "Search this board", count: findMatches.count)
				.opacity(isCovered ? 0 : 1)
				.allowsHitTesting(!isCovered)
				.transition(.move(edge: .top).combined(with: .opacity))
		}
	}

	func startFind() {
		pick = nil
		// The keyboard changing the room mustn't fit the board over a match
		keepsFitting = false
		withAnimation(motion) {
			find = FindState()
		}
	}

	/// Selects the match and brings it to the middle of what's free, at the zoom the person chose
	func reveal(_ match: CanvasFindMatch?) {
		guard let match else { return }
		selection = match.selection

		let scale = canvasBoard.transform.scale
		let free = room.free
		let offset = CGSize(
			width: free.midX - match.position.x * scale,
			height: free.midY - match.position.y * scale
		)
		canvasBoard.move(to: CanvasTransform(offset: offset, scale: scale), animation: motion)
	}
}

private nonisolated extension BoardSource.Content {
	var findText: String {
		switch self {
			case let .text(text):
				text
			case let .link(url, title):
				"\(title ?? "") \(url.absoluteString)"
		}
	}
}
