//
//  CanvasBoard+AppKit.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

#if os(macOS)
	import AppKit
	import ErgoLogic
	import ErgoSync
	import SwiftUI

	/// The board's boxes and arrows, with pan and zoom, on the Mac. The same as the iOS `CanvasBoard` in `CanvasBoard.swift`,
	/// with the AppKit `CanvasBoardView` doing the moving, and each box still the SwiftUI `CanvasBox`, hosted on its own.
	/// Keep the two property lists the same.
	struct CanvasBoard: NSViewRepresentable {
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

		/// Links and text dropped on the canvas from another app
		let dropSources: ([BoardSource.Content], CanvasPoint) -> Void

		func makeNSView(context _: Context) -> CanvasBoardView {
			let view = CanvasBoardView()
			controller.view = view
			return view
		}

		func updateNSView(_ view: CanvasBoardView, context: Context) {
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
			view.dropSources = dropSources
			view.boxContent = boxContent
			view.sourceContent = sourceContent
			view.handleContent = handleContent

			// Only the Mac has keys that do what a box's menu does
			view.boxActions = actions
			view.sourceActions = sourceActions

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
#endif
