//
//  CanvasBoard.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoSync
import SwiftUI

/// The board's boxes and arrows, with pan and zoom. `CanvasBoardView` does the moving in UIKit, and each box is
/// still the SwiftUI `CanvasBox`, hosted on its own.
struct CanvasBoard: UIViewRepresentable {
	let boxes: [CanvasBoxModel]
	let links: [Link]
	let strengths: [Link.ID: BoardArrowStrength]
	let notedLinks: Set<Link.ID>
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
	let showAnalysis: (BoardAnalysisTarget) -> Void

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
		view.showAnalysis = showAnalysis
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
				strengths: strengths,
				notedLinks: notedLinks,
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
