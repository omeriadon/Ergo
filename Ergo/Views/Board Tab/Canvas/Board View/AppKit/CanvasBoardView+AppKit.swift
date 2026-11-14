//
//  CanvasBoardView+AppKit.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

#if os(macOS)
	import AppKit
	import ErgoLogic
	import ErgoSync
	import SwiftUI

	// What the shared code reaches on `CanvasBoardView`, and so what this Mac one has to match the iOS one on:
//
	// From `CanvasBoard` (make and update):
	//   init(), isReadOnly, dragStarted, moved, tapBackground, connectStarted, connectTargetChanged, connectEnded,
	//   deleteLink, sourceDragStarted, sourceMoved, showAnalysis, boxContent, sourceContent, handleContent,
	//   addBoxes(_:animated:), addSources(_:animated:),
	//   update(boxes:links:strengths:notedLinks:sources:regions:selectedStatement:selectedLink:selectedSource:animated:)
	// From `CanvasBoardController`:
	//   move(to:animation:), canvasTransform, hasBeenMoved, box(_:) (an NSView here, a UIView on iOS)
	// Shared types declared with the iOS view, so declared here too: `ConnectionDrop`.
//
	// Mac only, set by `CanvasBoard` so keys can reach what a box's own menu does: boxActions, sourceActions. And
	// dropSources, for what's dragged in from other apps.

	/// Where an arrow being drawn was let go
	enum ConnectionDrop {
		case box(Statement.ID)

		/// On empty canvas, here
		case space(CanvasPoint)

		/// Cancelled, or back on the box or handle it came from
		case nowhere
	}

	/// The canvas in AppKit, the Mac's counterpart of the UIKit `CanvasBoardView`. Panning, zooming, dragging a box and the
	/// arrows all move views and layers directly, so SwiftUI isn't involved while something moves. What a box looks like is
	/// still SwiftUI, in `CanvasBox` and `StatementBoxView`, hosted per box.
	///
	/// AppKit views have no `transform`, so the pan and zoom are carried by `content`'s bounds instead: `content` covers the
	/// whole view, and its bounds are the part of the canvas on screen. A view whose bounds are smaller than its frame draws
	/// everything inside it larger, which is how `NSScrollView` zooms too. Boxes sit in `content` at their canvas positions, so
	/// moving the whole canvas is still one change however many boxes there are, and AppKit converts clicks and drags into
	/// canvas units for free.
	///
	/// Every view here is flipped, so y grows downwards and the maths is the same as on iOS.
	final class CanvasBoardView: NSView, NSGestureRecognizerDelegate {
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
		var showAnalysis: (BoardAnalysisTarget) -> Void = { _ in }

		/// Links and text dragged in from another app, with where they were let go (`CanvasBoardView+Dropping`)
		var dropSources: ([BoardSource.Content], CanvasPoint) -> Void = { _, _ in }

		var boxContent: (CanvasBoxModel, _ isNew: Bool) -> AnyView = { _, _ in AnyView(EmptyView()) }
		var sourceContent: (CanvasSourceModel, _ isNew: Bool) -> AnyView = { _, _ in AnyView(EmptyView()) }
		var handleContent: (_ pointsUp: Bool) -> AnyView = { _ in AnyView(EmptyView()) }

		/// What a box's and a source's own menus do, so Delete and Return can do the same to the selected one. The iOS view
		/// has no keyboard, so it doesn't need these.
		var boxActions: ((Statement) -> BoxActions)?
		var sourceActions: ((BoardSource) -> SourceActions)?

		var canvasTransform = CanvasTransform()
		var hasBeenMoved = false

		let content = CanvasContentView()

		/// Holds the region and arrow layers under every box. A view of its own so its layers are scaled with the boxes,
		/// whichever way AppKit carries `content`'s bounds down to its subviews.
		let shapes = CanvasShapesView()
		var regionLayer: CALayer {
			shapes.regionLayer
		}

		var arrowLayer: CALayer {
			shapes.arrowLayer
		}

		var cells: [Statement.ID: CanvasBoxCell] = [:]
		var arrows: [Link.ID: CanvasArrow] = [:]
		var links: [Link] = []

		/// What the analysis made of each arrow, for how its line is drawn
		var strengths: [Link.ID: BoardArrowStrength] = [:]

		/// The arrows the analysis wrote something about, beyond how strong they are
		var notedLinks: Set<Link.ID> = []

		/// The labels on arrows with something to say
		var arrowNotes: [Link.ID: CanvasArrowNote] = [:]
		var sourceCells: [BoardSource.ID: CanvasSourceCell] = [:]
		var regions: [CanvasRegionModel] = []
		/// The boxes and sources the outlines and arrows were last drawn for, so an update that changes neither can skip redrawing them
		var laidOutBoxes: [CanvasBoxModel] = []
		var laidOutSources: [CanvasSourceModel] = []
		var regionShapes: [BoardSource.ID: CanvasRegionLayer] = [:]
		var selectedStatement: Statement.ID?
		var selectedLink: Link.ID?
		var selectedSource: BoardSource.ID?

		/// While connecting or picking the other end of an arrow, boxes are tapped rather than dragged from, so hovering
		/// doesn't bring the handles out. The view only learns this from how the boxes look: those two looks only happen then.
		var isPicking = false

		/// The box under the pointer, which gets the handles on a Mac even when it isn't selected
		var hoveredStatement: Statement.ID?

		/// The arrow under the pointer, drawn a little stronger
		var hoveredLink: Link.ID?

		/// The box or source under the pointer, lifted a little
		weak var hoveredCell: CanvasHostedCell?

		/// The box the handles are on right now, which is what a drag from one connects
		var handleOwner: Statement.ID?

		/// One above a box and one below it, made the first time they're needed
		var handles: [CanvasHandleView] = []

		/// An arrow being dragged out of a handle, and whether the box it's from is the conclusion
		var connection: (source: Statement.ID, target: Statement.ID?, arrow: CanvasArrow, asConclusion: Bool)?

		// TODO: The drop lens (`CanvasDropLensView` on iOS) that shows where letting go of an arrow would make a new box.

		/// A box under the pointer, and where it was picked up
		var draggedBox: (id: Statement.ID, origin: CGPoint)?

		/// A source under the pointer with where it and its cards were picked up, since they move together
		var draggedSource: (id: BoardSource.ID, origin: CGPoint, members: [(id: Statement.ID, origin: CGPoint)])?

		/// A press on empty canvas: where it went down and where it was last, in this view's coordinates. It pans once it
		/// moves far enough, and is a click otherwise.
		var backgroundPress: (start: CGPoint, last: CGPoint, isPanning: Bool)?

		/// The grid point nearest what's being dragged, to tell when it reaches the next one
		var gridPoint: CanvasPoint?

		init() {
			super.init(frame: .zero)
			wantsLayer = true
			content.wantsLayer = true
			content.addSubview(shapes)
			addSubview(content)
			registerForDraggedTypes(Self.droppedTypes)

			// Follows the view's visible part by itself, so it never needs replacing
			addTrackingArea(NSTrackingArea(
				rect: .zero,
				options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
				owner: self,
				userInfo: nil
			))
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use CanvasBoardView()")
		}

		override var isFlipped: Bool {
			true
		}

		override var acceptsFirstResponder: Bool {
			true
		}

		override func layout() {
			super.layout()
			// Resizing `content` rescales its bounds, so the pan and zoom are put back straight after
			content.frame = bounds
			applyTransform()
		}

		override func viewDidChangeEffectiveAppearance() {
			super.viewDidChangeEffectiveAppearance()
			styleArrows()
			styleRegions()
		}

		/// AppKit hands this a point in the superview's coordinates. Handles are checked first since they sit over the boxes,
		/// then the boxes from the top down. Anything else is the canvas itself.
		override func hitTest(_ point: NSPoint) -> NSView? {
			let local = unsafe convert(point, from: superview)
			guard bounds.contains(local) else { return nil }
			return hitView(at: local)
		}

		/// What a click at `local`, in this view's points, would land on
		func hitView(at local: CGPoint) -> NSView {
			for handle in handles where !handle.isHidden && handle.alphaValue > 0.5 {
				// A handle's superview is this view, so it takes `local` as it is
				if let hit = handle.hitTest(local) {
					return hit
				}
			}
			let inContent = content.convert(local, from: self)
			for view in content.subviews.reversed() where view !== shapes {
				if let hit = view.hitTest(inContent) {
					return hit
				}
			}
			return self
		}

		// MARK: - From SwiftUI

		func box(_ id: Statement.ID) -> NSView? {
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
			notedLinks: Set<Link.ID>,
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
			if let hoveredStatement, !wanted.contains(hoveredStatement) {
				self.hoveredStatement = nil
			}

			// Inside `CanvasBoard`'s animation, a box that moved slides there through its animator
			for model in boxes {
				let id = model.statement.id
				guard let cell = cells[id] else { continue }
				cell.show(model, content: boxContent)
				let isHeld = draggedBox?.id == id || draggedSource?.members.contains { $0.id == id } == true
				if !isHeld {
					cell.setCenter(model.statement.position.point, animated: animated)
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
					cell.setCenter(model.source.position.point, animated: animated)
				}
			}

			if let selectedStatement, draggedBox == nil, let cell = cells[selectedStatement] {
				bringToFront(cell)
			}
			if let selectedSource, draggedSource == nil, let cell = sourceCells[selectedSource] {
				bringToFront(cell)
			}

			isPicking = boxes.contains { $0.appearance == .connectSource || $0.appearance == .unavailable }

			// Outlines and arrows only depend on where things are and how they connect, so they're redrawn when one of those changes.
			// Dragging redraws its own region as it moves, and the model follows when it lets go.
			let layoutChanged = boxes != laidOutBoxes || sources != laidOutSources
				|| links != self.links || strengths != self.strengths || notedLinks != self.notedLinks || regions != self.regions
				|| selectedStatement != self.selectedStatement || selectedLink != self.selectedLink
			self.links = links
			self.strengths = strengths
			self.notedLinks = notedLinks
			self.regions = regions
			self.selectedStatement = selectedStatement
			self.selectedLink = selectedLink
			self.selectedSource = selectedSource
			if let hoveredLink, !links.contains(where: { $0.id == hoveredLink }) {
				self.hoveredLink = nil
			}
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
			canvasTransform = transform
			if let animation {
				NSAnimationContext.animate(animation) {
					applyTransform(animated: true)
					updateHandles(slides: true)
				}
			} else {
				applyTransform()
				updateHandles()
			}
		}

		/// Puts `canvasTransform` on screen: the part of the canvas showing is the view's size divided by the zoom, starting
		/// where the offset puts the canvas's origin. A canvas point then lands at `canvas * scale + offset`, as on iOS.
		func applyTransform(animated: Bool = false) {
			let scale = max(canvasTransform.scale, 0.01)
			let visible = CGRect(
				x: -canvasTransform.offset.width / scale,
				y: -canvasTransform.offset.height / scale,
				width: bounds.width / scale,
				height: bounds.height / scale
			)
			if animated {
				content.animator().bounds = visible
			} else {
				content.bounds = visible
			}
			positionHandles(animated: animated)
		}

		/// Zooms by `factor` and keeps what's under `anchor` (a point in this view) where it is
		func zoom(by factor: CGFloat, about anchor: CGPoint, animation: Animation? = nil) {
			hasBeenMoved = true
			let transform = canvasTransform.zoomed(to: canvasTransform.scale * factor, about: anchor)
			if let animation {
				move(to: transform, animation: animation)
			} else {
				canvasTransform = transform
				applyTransform()
			}
		}

		/// Pans by `travel`, in this view's points
		func pan(by travel: CGSize) {
			hasBeenMoved = true
			canvasTransform.offset.width += travel.width
			canvasTransform.offset.height += travel.height
			applyTransform()
		}

		// MARK: - Colours

		/// A colour as it looks in this view's light or dark appearance, for the layers, which don't follow it on their own
		func resolved(_ color: NSColor) -> CGColor {
			var resolved = color.cgColor
			effectiveAppearance.performAsCurrentDrawingAppearance {
				resolved = color.cgColor
			}
			return resolved
		}

		/// The board's accent, resolved for the layers
		var accentColor: CGColor {
			resolved(NSColor(Color.accent))
		}
	}

	// MARK: - Containers

	/// The canvas's coordinate space. Its bounds carry the pan and zoom, set by `CanvasBoardView.applyTransform`.
	final class CanvasContentView: NSView {
		override var isFlipped: Bool {
			true
		}
	}

	/// Holds the region and arrow layers. It takes no clicks: an arrow is chosen by where a click on the background lands.
	final class CanvasShapesView: NSView {
		let regionLayer = CALayer()
		let arrowLayer = CALayer()

		/// Made here rather than by AppKit so the region and arrow layers can be added before the view is in a window
		private let root = CALayer()

		init() {
			super.init(frame: .zero)
			root.addSublayer(regionLayer)
			root.addSublayer(arrowLayer)
			wantsLayer = true
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use init()")
		}

		override var isFlipped: Bool {
			true
		}

		override func makeBackingLayer() -> CALayer {
			root
		}

		override func hitTest(_: NSPoint) -> NSView? {
			nil
		}
	}
#endif
