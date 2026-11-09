//
//  CanvasBoardView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import ErgoSync
import SwiftUI
import UIKit

/// Where an arrow being drawn was let go
enum ConnectionDrop {
	case box(Statement.ID)

	/// On empty canvas, here
	case space(CanvasPoint)

	/// Cancelled, or back on the box or handle it came from
	case nowhere
}

/// The canvas in UIKit, because following a finger through SwiftUI redraws too much for every frame. Pan, pinch, inertia,
/// dragging a box and the arrows all move layers directly, so SwiftUI isn't involved at all while something moves.
/// What a box looks like is SwiftUI, in `CanvasBox` and `StatementBoxView`.
///
/// `content` is a zero-sized view that carries the pan and zoom as its transform. Boxes sit in it at their canvas
/// positions, so moving the whole canvas is one transform however many boxes there are.
final class CanvasBoardView: UIView, UIGestureRecognizerDelegate, UIContextMenuInteractionDelegate {
	/// For a board this person can only view: panning and zooming stay, and dragging, connecting and the arrow menu go
	var isReadOnly = false

	var dragStarted: (Statement.ID) -> Void = { _ in }
	var moved: (Statement.ID, CanvasPoint) -> Void = { _, _ in }
	var tapBackground: (CanvasPoint) -> Void = { _ in }
	var connectStarted: (Statement.ID, _ asConclusion: Bool) -> Void = { _, _ in }
	var connectTargetChanged: (Statement.ID?) -> Void = { _ in }

	var connectEnded: (Statement.ID, ConnectionDrop) -> Void = { _, _ in }
	var deleteLink: (Link.ID) -> Void = { _ in }
	var sourceDragStarted: (BoardSource.ID) -> Void = { _ in }
	var sourceMoved: (BoardSource.ID, CanvasPoint) -> Void = { _, _ in }

	var boxContent: (CanvasBoxModel, _ isNew: Bool) -> AnyView = { _, _ in AnyView(EmptyView()) }
	var sourceContent: (CanvasSourceModel, _ isNew: Bool) -> AnyView = { _, _ in AnyView(EmptyView()) }
	var handleContent: (_ pointsUp: Bool) -> AnyView = { _ in AnyView(EmptyView()) }

	var canvasTransform = CanvasTransform()
	var hasBeenMoved = false

	let content = UIView()
	let regionLayer = CALayer()
	let arrowLayer = CALayer()

	var cells: [Statement.ID: CanvasBoxCell] = [:]
	var arrows: [Link.ID: CanvasArrow] = [:]
	var links: [Link] = []

	/// What the analysis made of each arrow, for how its line is drawn
	var strengths: [Link.ID: BoardArrowStrength] = [:]
	var sourceCells: [BoardSource.ID: CanvasSourceCell] = [:]
	var regions: [CanvasRegionModel] = []
	/// The boxes and sources the outlines and arrows were last drawn for, so an update that changes neither can skip redrawing them
	var laidOutBoxes: [CanvasBoxModel] = []
	var laidOutSources: [CanvasSourceModel] = []
	var regionLayers: [BoardSource.ID: CanvasRegionLayer] = [:]
	var selectedStatement: Statement.ID?
	var selectedLink: Link.ID?

	/// One above the selected box and one below it, made the first time they're needed
	var handles: [CanvasHandleView] = []

	/// An arrow being dragged out of a handle, and whether the box it's from is the conclusion
	var connection: (source: Statement.ID, target: Statement.ID?, arrow: CanvasArrow, asConclusion: Bool)?

	/// Under the finger while letting go of that arrow would make a new box. Over the boxes and arrows, made the first
	/// time it's needed.
	lazy var dropLens: CanvasDropLensView = {
		let lens = CanvasDropLensView()
		insertSubview(lens, aboveSubview: content)
		return lens
	}()

	lazy var panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned))
	lazy var pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
	lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
	lazy var touchDownRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(touchedDown))

	/// A box under the finger, and where it was picked up
	var draggedBox: (id: Statement.ID, origin: CGPoint)?

	/// A source under the finger with where it and its cards were picked up, since they move together
	var draggedSource: (id: BoardSource.ID, origin: CGPoint, members: [(id: Statement.ID, origin: CGPoint)])?

	lazy var haptics = CanvasHaptics(view: self)

	/// The grid point nearest what's being dragged, to tell when it reaches the next one
	var gridPoint: CanvasPoint?

	var pinchStart = CanvasTransform()
	var pinchAnchor = CGPoint.zero
	var glideLink: CADisplayLink?
	var glideVelocity = CGSize.zero
	var glideTime: CFTimeInterval?

	/// The last touch only stopped the canvas, so it means nothing else, like the first touch on a moving scroll view
	var touchStoppedGlide = false

	init() {
		super.init(frame: .zero)
		backgroundColor = .clear
		isOpaque = false

		content.layer.addSublayer(regionLayer)
		content.layer.addSublayer(arrowLayer)
		addSubview(content)

		panRecognizer.maximumNumberOfTouches = 1
		tapRecognizer.cancelsTouchesInView = false
		touchDownRecognizer.minimumPressDuration = 0
		touchDownRecognizer.cancelsTouchesInView = false
		for recognizer in [panRecognizer, pinchRecognizer, tapRecognizer, touchDownRecognizer] {
			recognizer.delegate = self
			addGestureRecognizer(recognizer)
		}

		addInteraction(UIContextMenuInteraction(delegate: self))

		registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _) in
			view.styleArrows()
			view.styleRegions()
		}
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use CanvasBoardView()")
	}

	override func willMove(toWindow newWindow: UIWindow?) {
		super.willMove(toWindow: newWindow)
		if newWindow == nil {
			stopGlide()
		}
	}

	/// `content` has no size, so UIKit wouldn't look inside it on its own
	override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		guard bounds.contains(point) else { return nil }

		// While the canvas glides a touch only stops it, so it can't pick up the box that happens to be under it
		if glideLink != nil {
			return self
		}
		for handle in handles where handle.alpha > 0.5 {
			if let hit = handle.hitTest(convert(point, to: handle), with: event) {
				return hit
			}
		}
		for cell in content.subviews.reversed() {
			if let hit = cell.hitTest(convert(point, to: cell), with: event) {
				return hit
			}
		}
		return self
	}

	// MARK: - From SwiftUI

	func box(_ id: Statement.ID) -> UIView? {
		cells[id]
	}

	/// Makes the boxes that aren't on the canvas yet. Called outside `update`'s animation, so a new box is simply at its
	/// position from the start, with nowhere to slide in from.
	func addBoxes(_ boxes: [CanvasBoxModel], animated: Bool) {
		for model in boxes where cells[model.statement.id] == nil {
			addCell(for: model, isNew: animated)
		}
	}

	/// The same for sources
	func addSources(_ sources: [CanvasSourceModel], animated: Bool) {
		for model in sources where sourceCells[model.source.id] == nil {
			addSourceCell(for: model, isNew: animated)
		}
	}

	func update(
		boxes: [CanvasBoxModel],
		links: [Link],
		strengths: [Link.ID: BoardArrowStrength],
		sources: [CanvasSourceModel],
		regions: [CanvasRegionModel],
		selectedStatement: Statement.ID?,
		selectedLink: Link.ID?,
		selectedSource: BoardSource.ID?,
		animated: Bool
	) {
		let wanted = Set(boxes.map(\.statement.id))
		for (id, cell) in cells where !wanted.contains(id) {
			cells[id] = nil
			remove(cell, animated: animated)
		}

		for model in boxes {
			let id = model.statement.id
			guard let cell = cells[id] else { continue }
			cell.show(model, content: boxContent)
			let isHeld = draggedBox?.id == id || draggedSource?.members.contains { $0.id == id } == true
			if !isHeld {
				cell.center = model.statement.position.point
			}
		}

		let wantedSources = Set(sources.map(\.source.id))
		for (id, cell) in sourceCells where !wantedSources.contains(id) {
			sourceCells[id] = nil
			remove(cell, animated: animated)
		}

		for model in sources {
			let id = model.source.id
			guard let cell = sourceCells[id] else { continue }
			cell.show(model, content: sourceContent)
			if draggedSource?.id != id {
				cell.center = model.source.position.point
			}
		}

		if let selectedStatement, draggedBox == nil, let cell = cells[selectedStatement] {
			content.bringSubviewToFront(cell)
		}
		if let selectedSource, draggedSource == nil, let cell = sourceCells[selectedSource] {
			content.bringSubviewToFront(cell)
		}

		// Outlines and arrows only depend on where things are and how they connect, so they're redrawn when one of those changes.
		// Dragging redraws its own region as it moves, and the model follows when it lets go.
		let layoutChanged = boxes != laidOutBoxes || sources != laidOutSources
			|| links != self.links || strengths != self.strengths || regions != self.regions
			|| selectedStatement != self.selectedStatement || selectedLink != self.selectedLink
		self.links = links
		self.strengths = strengths
		self.regions = regions
		self.selectedStatement = selectedStatement
		self.selectedLink = selectedLink
		if layoutChanged {
			laidOutBoxes = boxes
			laidOutSources = sources
			updateRegions(animation: animated ? 0.5 : nil)
			updateArrows(animation: animated ? 0.5 : nil)
		} else {
			styleRegions()
		}
		updateHandles()
	}

	func move(to transform: CanvasTransform, animation: Animation?) {
		stopGlide()
		canvasTransform = transform
		if let animation {
			UIView.animate(animation) {
				applyTransform()
				updateHandles()
			}
		} else {
			applyTransform()
			updateHandles()
		}
	}

	func applyTransform() {
		content.transform = CGAffineTransform(
			a: canvasTransform.scale, b: 0,
			c: 0, d: canvasTransform.scale,
			tx: canvasTransform.offset.width, ty: canvasTransform.offset.height
		)
		positionHandles()
	}
}
