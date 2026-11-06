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
	let letters: [String]
	let descriptors: [String]
	let relations: BoxRelations
	let verdict: BoxVerdict?
	let appearance: BoxAppearance
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

	func move(to transform: CanvasTransform, animation: Animation?) {
		if let view {
			view.move(to: transform, animation: animation)
		} else {
			pending = transform
		}
	}
}

/// The page's boxes and arrows, with pan and zoom. `CanvasBoardView` does the moving in UIKit, and each box is
/// still the SwiftUI `CanvasBox`, hosted on its own.
struct CanvasBoard: UIViewRepresentable {
	let boxes: [CanvasBoxModel]
	let links: [Link]
	let selectedStatement: Statement.ID?
	let selectedLink: Link.ID?
	let controller: CanvasBoardController

	/// A hosted box has its own SwiftUI environment, so what it needs from the app's is passed in
	let catalog: CatalogStore

	let actions: (Statement) -> BoxActions
	let dragStarted: (Statement.ID) -> Void
	let moved: (Statement.ID, CanvasPoint) -> Void
	let tapBackground: (CanvasPoint) -> Void
	let connectStarted: (Statement.ID) -> Void
	let connectTargetChanged: (Statement.ID?) -> Void
	let connectEnded: (Statement.ID, Statement.ID?) -> Void

	func makeUIView(context _: Context) -> CanvasBoardView {
		let view = CanvasBoardView()
		controller.view = view
		return view
	}

	func updateUIView(_ view: CanvasBoardView, context: Context) {
		view.dragStarted = dragStarted
		view.moved = moved
		view.tapBackground = tapBackground
		view.connectStarted = connectStarted
		view.connectTargetChanged = connectTargetChanged
		view.connectEnded = connectEnded
		view.boxContent = boxContent
		view.handleContent = handleContent

		let animated = context.transaction.animation != nil
		context.animate {
			view.update(
				boxes: boxes,
				links: links,
				selectedStatement: selectedStatement,
				selectedLink: selectedLink,
				animated: animated
			)
		}
	}

	private func boxContent(_ model: CanvasBoxModel) -> any UIContentConfiguration {
		UIHostingConfiguration {
			CanvasBox(model: model, actions: actions(model.statement))
				.environment(catalog)
				.fontDesign(.rounded)
		}
		.margins(.all, 0)
	}

	private func handleContent(pointsUp: Bool) -> any UIContentConfiguration {
		UIHostingConfiguration {
			CanvasConnectHandle(pointsUp: pointsUp)
		}
		.margins(.all, 0)
	}
}
