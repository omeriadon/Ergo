//
//  CanvasView+Sources.swift
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
	// MARK: - Sources

	/// A source can't be the answer to a pick, so tapping one just ends it
	func selectSource(_ id: BoardSource.ID) {
		pick = nil
		selection = .source(id)
	}

	/// Links always go to the browser, never a view in the app. Text opens its editor.
	func open(_ id: BoardSource.ID) {
		pick = nil
		selection = .source(id)
		guard let source = board.source(id) else { return }

		if let link = source.link {
			if link.isWebLink {
				#if os(iOS)
					UIApplication.shared.open(link)
				#else
					NSWorkspace.shared.open(link)
				#endif
			}
		} else {
			sourceSheet = .edit(id)
		}
	}

	func sourceDragStarted(_ id: BoardSource.ID) {
		pick = nil
		selection = .source(id)
		dragBefore = history.snapshot()
	}

	func sourceMoved(_ id: BoardSource.ID, to position: CanvasPoint) {
		boardStore.moveSource(id: id, to: position)
		history.register(dragBefore, name: "Move Source")
		dragBefore = nil
	}

	func nudgeSource(_ id: BoardSource.ID, columns: Int, rows: Int) {
		guard let source = board.source(id) else { return }
		let target = CanvasGrid.snapped(CanvasPoint(
			x: source.position.x + Double(columns) * CanvasGrid.step,
			y: source.position.y + Double(rows) * CanvasGrid.step
		))
		history.perform("Move Source") {
			boardStore.moveSource(id: id, to: target)
		}
	}

	func deleteSource(_ id: BoardSource.ID) {
		history.perform("Delete Source") {
			withAnimation(motion) {
				boardStore.deleteSource(id: id)
			}
		}
	}

	/// A new source where the person is looking
	func addSource(_ content: BoardSource.Content) {
		var added: BoardSource.ID?
		history.perform("Add Source") {
			withAnimation(motion) {
				let id = boardStore.addSource(content, at: freeSpot(near: viewCentre))
				selection = .source(id)
				added = id
			}
		}
		if keepsFitting, !canvasBoard.hasBeenMoved {
			fit(animated: true)
		}
		keepsFitting = false
		if let added {
			findTitle(of: added)
		}
	}

	/// What was dropped on the canvas from another app, as sources where it landed. One undo step for the lot, and the
	/// canvas stays where it is, since the person chose the spot.
	func addSources(_ contents: [BoardSource.Content], at point: CanvasPoint) {
		guard !isReadOnly, !contents.isEmpty else { return }
		var added: [BoardSource.ID] = []
		history.perform("Add Source") {
			withAnimation(motion) {
				for content in contents {
					added.append(boardStore.addSource(content, at: freeSpot(near: point)))
				}
				if let last = added.last {
					selection = .source(last)
				}
			}
		}
		pick = nil
		keepsFitting = false
		added.forEach(findTitle(of:))
	}

	/// A link typed in has no title, and the card says more with the page's. It's fine if the page won't load.
	func findTitle(of id: BoardSource.ID) {
		guard case let .link(url, nil)? = board.source(id)?.content else { return }
		Task {
			guard let title = try? await PageReader.read(url).title else { return }
			boardStore.updateSource(id, content: .link(url, title: title))
		}
	}

	func sourceSheet(for sheet: SourceSheet) -> CanvasSourceSheet {
		CanvasSourceSheet(
			sheet: sheet,
			source: sheet.sourceID.flatMap { board.source($0) },
			isReadOnly: isReadOnly,
			add: addSource,
			update: { id, content in
				boardStore.updateSource(id, content: content)
				findTitle(of: id)
			}
		)
	}
}
