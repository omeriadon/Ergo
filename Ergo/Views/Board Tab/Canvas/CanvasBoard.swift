//
//  CanvasBoard.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// What one box shows. Compared before its SwiftUI is touched, so a box only redraws when this changes.
struct CanvasBoxModel: Equatable {
	let statement: Statement
	let relations: BoxRelations
	let appearance: BoxAppearance

	/// In the model so a role changing redraws the box. A hosted box can't read it from the app's environment.
	var isReadOnly = false
}

/// What one source shows, compared the same way
struct CanvasSourceModel: Equatable {
	let source: BoardSource
	let appearance: BoxAppearance
	var isReadOnly = false
}

/// A source and the cards in its region. Where they are is read from the views, so the shape follows a drag.
struct CanvasRegionModel: Equatable {
	let source: BoardSource.ID
	let members: [Statement.ID]
}

/// How SwiftUI reaches the pan and zoom, which live in `CanvasBoardView` so they never have to go through a SwiftUI update
@MainActor
final class CanvasBoardController {
	var view: CanvasBoardView? {
		didSet {
			if let pending, let view {
				view.move(to: pending, animation: nil)
				self.pending = nil
			}
		}
	}

	/// A fit asked for before the view exists
	private var pending: CanvasTransform?

	var transform: CanvasTransform {
		view?.canvasTransform ?? pending ?? CanvasTransform()
	}

	/// Whether the person has panned or zoomed yet
	var hasBeenMoved: Bool {
		view?.hasBeenMoved ?? false
	}

	/// The view of a box on the canvas, for the editor to zoom out of
	func box(_ id: Statement.ID) -> UIView? {
		view?.box(id)
	}

	func move(to transform: CanvasTransform, animation: Animation?) {
		if let view {
			view.move(to: transform, animation: animation)
		} else {
			pending = transform
		}
	}
}

/// The board's boxes and arrows, with pan and zoom. `CanvasBoardView` does the moving in UIKit, and each box is
/// still the SwiftUI `CanvasBox`, hosted on its own.
struct CanvasBoard: UIViewRepresentable {
	let boxes: [CanvasBoxModel]
	let links: [Link]
	let sources: [CanvasSourceModel]
	let regions: [CanvasRegionModel]
	let selectedStatement: Statement.ID?
	let selectedLink: Link.ID?
	let selectedSource: BoardSource.ID?
	let controller: CanvasBoardController

	/// Nothing can be dragged or connected, for someone who can only view this board
	let isReadOnly: Bool

	/// A hosted box has its own SwiftUI environment, so anything it needs from the app's has to be passed in
	let actions: (Statement) -> BoxActions
	let sourceActions: (BoardSource) -> SourceActions
	let dragStarted: (Statement.ID) -> Void
	let moved: (Statement.ID, CanvasPoint) -> Void
	let tapBackground: (CanvasPoint) -> Void
	let connectStarted: (Statement.ID, _ asConclusion: Bool) -> Void
	let connectTargetChanged: (Statement.ID?) -> Void
	let connectEnded: (Statement.ID, ConnectionDrop) -> Void
	let deleteLink: (Link.ID) -> Void
	let sourceDragStarted: (BoardSource.ID) -> Void
	let sourceMoved: (BoardSource.ID, CanvasPoint) -> Void

	func makeUIView(context _: Context) -> CanvasBoardView {
		let view = CanvasBoardView()
		controller.view = view
		return view
	}

	func updateUIView(_ view: CanvasBoardView, context: Context) {
		view.isReadOnly = isReadOnly
		view.dragStarted = dragStarted
		view.moved = moved
		view.tapBackground = tapBackground
		view.connectStarted = connectStarted
		view.connectTargetChanged = connectTargetChanged
		view.connectEnded = connectEnded
		view.deleteLink = deleteLink
		view.sourceDragStarted = sourceDragStarted
		view.sourceMoved = sourceMoved
		view.boxContent = boxContent
		view.sourceContent = sourceContent
		view.handleContent = handleContent

		let animated = context.transaction.animation != nil
		view.addBoxes(boxes, animated: animated)
		view.addSources(sources, animated: animated)
		context.animate {
			view.update(
				boxes: boxes,
				links: links,
				sources: sources,
				regions: regions,
				selectedStatement: selectedStatement,
				selectedLink: selectedLink,
				selectedSource: selectedSource,
				animated: animated
			)
		}
	}

	private func boxContent(_ model: CanvasBoxModel, isNew: Bool) -> AnyView {
		AnyView(
			CanvasBox(model: model, actions: actions(model.statement))
				.modifier(BoxEntrance(isNew: isNew))
				.fontDesign(.rounded)
		)
	}

	private func sourceContent(_ model: CanvasSourceModel, isNew: Bool) -> AnyView {
		AnyView(
			CanvasSourceBox(model: model, actions: sourceActions(model.source))
				.modifier(BoxEntrance(isNew: isNew))
				.fontDesign(.rounded)
		)
	}

	private func handleContent(pointsUp: Bool) -> AnyView {
		AnyView(CanvasConnectHandle(pointsUp: pointsUp))
	}
}
