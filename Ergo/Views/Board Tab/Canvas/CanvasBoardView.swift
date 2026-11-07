//
//  CanvasBoardView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
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

	private(set) var canvasTransform = CanvasTransform()
	private(set) var hasBeenMoved = false

	private let content = UIView()
	private let regionLayer = CALayer()
	private let arrowLayer = CALayer()

	private var cells: [Statement.ID: CanvasBoxCell] = [:]
	private var arrows: [Link.ID: CanvasArrow] = [:]
	private var links: [Link] = []
	private var sourceCells: [BoardSource.ID: CanvasSourceCell] = [:]
	private var regions: [CanvasRegionModel] = []
	private var regionLayers: [BoardSource.ID: CanvasRegionLayer] = [:]
	private var selectedStatement: Statement.ID?
	private var selectedLink: Link.ID?

	/// One above the selected box and one below it, made the first time they're needed
	private var handles: [CanvasHandleView] = []

	/// An arrow being dragged out of a handle, and whether the box it's from is the conclusion
	private var connection: (source: Statement.ID, target: Statement.ID?, arrow: CanvasArrow, asConclusion: Bool)?

	/// Under the finger while letting go of that arrow would make a new box. Over the boxes and arrows, made the first
	/// time it's needed.
	private lazy var dropLens: CanvasDropLensView = {
		let lens = CanvasDropLensView()
		insertSubview(lens, aboveSubview: content)
		return lens
	}()

	private lazy var panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned))
	private lazy var pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
	private lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
	private lazy var touchDownRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(touchedDown))

	/// A box under the finger, and where it was picked up
	private var draggedBox: (id: Statement.ID, origin: CGPoint)?

	/// A source under the finger with where it and its cards were picked up, since they move together
	private var draggedSource: (id: BoardSource.ID, origin: CGPoint, members: [(id: Statement.ID, origin: CGPoint)])?

	private lazy var haptics = CanvasHaptics(view: self)

	/// The grid point nearest what's being dragged, to tell when it reaches the next one
	private var gridPoint: CanvasPoint?

	private var pinchStart = CanvasTransform()
	private var pinchAnchor = CGPoint.zero
	private var glideLink: CADisplayLink?
	private var glideVelocity = CGSize.zero
	private var glideTime: CFTimeInterval?

	/// The last touch only stopped the canvas, so it means nothing else, like the first touch on a moving scroll view
	private var touchStoppedGlide = false

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

		self.links = links
		self.regions = regions
		self.selectedStatement = selectedStatement
		self.selectedLink = selectedLink
		updateRegions(animation: animated ? 0.5 : nil)
		updateArrows(animation: animated ? 0.5 : nil)
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

	private func applyTransform() {
		content.transform = CGAffineTransform(
			a: canvasTransform.scale, b: 0,
			c: 0, d: canvasTransform.scale,
			tx: canvasTransform.offset.width, ty: canvasTransform.offset.height
		)
		positionHandles()
	}

	// MARK: - Boxes

	private func addCell(for model: CanvasBoxModel, isNew: Bool) {
		let cell = CanvasBoxCell(model: model, isNew: isNew, content: boxContent)
		content.addSubview(cell)

		let drag = UIPanGestureRecognizer(target: self, action: #selector(boxPanned))
		drag.maximumNumberOfTouches = 1
		drag.delegate = self
		cell.addGestureRecognizer(drag)

		cells[model.statement.id] = cell
	}

	private func remove(_ cell: UIView, animated: Bool) {
		guard animated else {
			cell.removeFromSuperview()
			return
		}
		UIView.animate(withDuration: 0.2) {
			cell.alpha = 0
		} completion: { _ in
			cell.removeFromSuperview()
		}
	}

	/// Follows the finger exactly, and only settles on the grid when it lifts
	@objc private func boxPanned(_ recognizer: UIPanGestureRecognizer) {
		guard let cell = recognizer.view as? CanvasBoxCell else { return }
		let id = cell.model.statement.id

		switch recognizer.state {
			case .began:
				stopGlide()
				draggedBox = (id, cell.center)
				content.bringSubviewToFront(cell)
				cell.isLifted = true
				gridPoint = CanvasGrid.snapped(CanvasPoint(cell.center))
				haptics.prepare()
				updateHandles()
				dragStarted(id)

			case .changed:
				guard let draggedBox, draggedBox.id == id else { return }
				let travel = recognizer.translation(in: content)
				cell.center = CGPoint(x: draggedBox.origin.x + travel.x, y: draggedBox.origin.y + travel.y)
				updateArrows(touching: id, animation: nil)
				updateRegion(holding: id, animation: nil)
				feelGrid(at: cell.center)

			case .ended, .cancelled, .failed:
				guard let draggedBox, draggedBox.id == id else { return }
				self.draggedBox = nil
				gridPoint = nil
				cell.isLifted = false

				let finished = recognizer.state == .ended
				let target = finished ? CanvasGrid.snapped(CanvasPoint(cell.center)) : CanvasPoint(draggedBox.origin)
				UIView.animate(springDuration: 0.25, bounce: 0) {
					cell.center = target.point
					updateHandles()
				}
				updateArrows(touching: id, animation: 0.25)
				updateRegion(holding: id, animation: 0.25)
				if finished {
					moved(id, target)
				}

			default:
				break
		}
	}

	// MARK: - Sources

	private func addSourceCell(for model: CanvasSourceModel, isNew: Bool) {
		let cell = CanvasSourceCell(model: model, isNew: isNew, content: sourceContent)
		content.addSubview(cell)

		let drag = UIPanGestureRecognizer(target: self, action: #selector(sourcePanned))
		drag.maximumNumberOfTouches = 1
		drag.delegate = self
		cell.addGestureRecognizer(drag)

		sourceCells[model.source.id] = cell
	}

	/// The source brings its region along: its cards follow the finger with it, and their arrows and the shape follow them
	@objc private func sourcePanned(_ recognizer: UIPanGestureRecognizer) {
		guard let cell = recognizer.view as? CanvasSourceCell else { return }
		let id = cell.model.source.id

		switch recognizer.state {
			case .began:
				stopGlide()
				let members = regions.first { $0.source == id }?.members ?? []
				draggedSource = (id, cell.center, members.compactMap { member in cells[member].map { (member, $0.center) } })
				content.bringSubviewToFront(cell)
				cell.isLifted = true
				gridPoint = CanvasGrid.snapped(CanvasPoint(cell.center))
				haptics.prepare()
				updateHandles()
				sourceDragStarted(id)

			case .changed:
				guard let draggedSource, draggedSource.id == id else { return }
				let travel = recognizer.translation(in: content)
				moveHeldSource(draggedSource, by: travel)
				for member in draggedSource.members {
					updateArrows(touching: member.id, animation: nil)
				}
				updateRegion(of: id, animation: nil)
				feelGrid(at: cell.center)

			case .ended, .cancelled, .failed:
				guard let held = draggedSource, held.id == id else { return }
				draggedSource = nil
				gridPoint = nil
				cell.isLifted = false

				let finished = recognizer.state == .ended
				let travel = recognizer.translation(in: content)
				let current = CGPoint(x: held.origin.x + travel.x, y: held.origin.y + travel.y)
				let target = finished ? CanvasGrid.snapped(CanvasPoint(current)) : CanvasPoint(held.origin)
				let settled = CGPoint(x: target.x - held.origin.x, y: target.y - held.origin.y)
				UIView.animate(springDuration: 0.25, bounce: 0) {
					moveHeldSource(held, by: settled)
				}
				for member in held.members {
					updateArrows(touching: member.id, animation: 0.25)
				}
				updateRegion(of: id, animation: 0.25)
				if finished {
					sourceMoved(id, target)
				}

			default:
				break
		}
	}

	private func moveHeldSource(_ held: (id: BoardSource.ID, origin: CGPoint, members: [(id: Statement.ID, origin: CGPoint)]), by travel: CGPoint) {
		sourceCells[held.id]?.center = CGPoint(x: held.origin.x + travel.x, y: held.origin.y + travel.y)
		for member in held.members {
			cells[member.id]?.center = CGPoint(x: member.origin.x + travel.x, y: member.origin.y + travel.y)
		}
	}

	// MARK: - Regions

	private func updateRegions(animation: TimeInterval?) {
		let wanted = Set(regions.map(\.source))
		for (id, layer) in regionLayers where !wanted.contains(id) {
			regionLayers[id] = nil
			layer.removeFromSuperlayer()
		}
		for region in regions {
			update(region, animation: animation)
		}
		styleRegions()
	}

	/// While a box moves, only the region it's in changes
	private func updateRegion(holding id: Statement.ID, animation: TimeInterval?) {
		for region in regions where region.members.contains(id) {
			update(region, animation: animation)
		}
	}

	private func updateRegion(of id: BoardSource.ID, animation: TimeInterval?) {
		for region in regions where region.source == id {
			update(region, animation: animation)
		}
	}

	private func update(_ region: CanvasRegionModel, animation: TimeInterval?) {
		guard let source = sourceCells[region.source]?.center else { return }

		let layer: CanvasRegionLayer
		if let existing = regionLayers[region.source] {
			layer = existing
		} else {
			layer = CanvasRegionLayer(in: regionLayer)
			regionLayers[region.source] = layer
		}

		let members = region.members.compactMap { cells[$0].map { CanvasPoint($0.center) } }
		let arrows = links.compactMap { link -> CanvasRegion.Arrow? in
			guard region.members.contains(link.premise), region.members.contains(link.conclusion),
			      let from = cells[link.premise]?.center, let to = cells[link.conclusion]?.center
			else { return nil }
			return CanvasRegion.Arrow(from: CanvasPoint(from), to: CanvasPoint(to))
		}
		layer.setOutline(CanvasRegion.outline(source: CanvasPoint(source), members: members, arrows: arrows), animation: animation)
	}

	private func styleRegions() {
		let accent = UIColor(Color.accentColor).resolvedColor(with: traitCollection)
		for layer in regionLayers.values {
			layer.style(accent: accent)
		}
	}

	/// A tap each time what's being dragged reaches the next grid point, which is where it would settle if let go
	private func feelGrid(at point: CGPoint) {
		let nearest = CanvasGrid.snapped(CanvasPoint(point))
		if let gridPoint, gridPoint != nearest {
			haptics.crossedGridLine()
		}
		gridPoint = nearest
	}

	// MARK: - Connecting

	/// Shows the handles on the selected box. Dragging the one above makes the box a conclusion of what it's dragged to,
	/// and dragging the one below makes it a premise. Let go on empty canvas, that other box is made there.
	private func updateHandles() {
		guard !isReadOnly, let id = selectedStatement, cells[id] != nil, draggedBox == nil, connection == nil else {
			for handle in handles where handle.alpha > 0 {
				UIView.animate(withDuration: 0.12) {
					handle.alpha = 0
				}
			}
			return
		}

		if handles.isEmpty {
			handles = [makeHandle(isAbove: true), makeHandle(isAbove: false)]
		}

		if handles.allSatisfy({ $0.alpha == 0 }) {
			UIView.performWithoutAnimation {
				positionHandles()
			}
		} else {
			positionHandles()
		}
		UIView.animate(withDuration: 0.12) {
			for handle in handles {
				handle.alpha = 1
			}
		}
	}

	private func positionHandles() {
		guard let id = selectedStatement, let box = cells[id] else { return }
		let center = canvasTransform.screen(CanvasPoint(box.center))
		let reach = CanvasLayout.boxSize.height / 2 * canvasTransform.scale + 8 + CanvasConnectHandle.size / 2
		for handle in handles {
			handle.center = CGPoint(x: center.x, y: center.y + (handle.isAbove ? -reach : reach))
		}
	}

	private func makeHandle(isAbove: Bool) -> CanvasHandleView {
		let handle = CanvasHandleView(isAbove: isAbove, content: handleContent)
		handle.alpha = 0

		let drag = UIPanGestureRecognizer(target: self, action: #selector(handlePanned))
		drag.maximumNumberOfTouches = 1
		drag.delegate = self
		handle.addGestureRecognizer(drag)

		addSubview(handle)
		return handle
	}

	@objc private func handlePanned(_ recognizer: UIPanGestureRecognizer) {
		switch recognizer.state {
			case .began:
				guard let source = selectedStatement, let handle = recognizer.view as? CanvasHandleView else { return }
				let arrow = CanvasArrow(in: arrowLayer)
				connection = (source, nil, arrow, handle.isAbove)
				styleArrows()
				haptics.prepare()
				updateHandles()
				connectStarted(source, handle.isAbove)
				followConnection(to: recognizer.location(in: content))

			case .changed:
				followConnection(to: recognizer.location(in: content))

			case .ended, .cancelled, .failed:
				guard let finished = connection else { return }
				let drop = recognizer.state == .ended ? connectionDrop(of: finished.source, over: finished.target, at: recognizer.location(in: self)) : .nowhere
				connection = nil
				gridPoint = nil
				dropLens.setShown(false)
				finished.arrow.removeFromSuperlayer()
				updateHandles()
				connectEnded(finished.source, drop)

			default:
				break
		}
	}

	private func connectionDrop(of source: Statement.ID, over target: Statement.ID?, at location: CGPoint) -> ConnectionDrop {
		if let target {
			return .box(target)
		}
		let point = canvasTransform.canvas(location)
		let isOnSource = cells[source].map { CanvasRect.box(at: CanvasPoint($0.center)).contains(point) } ?? true
		let isOnHandle = handles.contains { $0.frame.contains(location) }
		return isOnSource || isOnHandle ? .nowhere : .space(point)
	}

	private func wouldMakeBox(from source: Statement.ID, over target: Statement.ID?, at location: CGPoint) -> Bool {
		guard cells.count < ArgumentMapValidator.defaultMaximumStatements,
		      case .space = connectionDrop(of: source, over: target, at: location)
		else {
			return false
		}
		return true
	}

	/// The arrow reaches for the box under the finger, and follows the finger when there isn't one
	private func followConnection(to point: CGPoint) {
		guard let current = connection, let source = cells[current.source]?.center else { return }

		let target = content.subviews.reversed()
			.compactMap { $0 as? CanvasBoxCell }
			.first { $0.model.statement.id != current.source && $0.frame.contains(point) }
		let targetID = target?.model.statement.id
		if targetID != current.target {
			connection?.target = targetID
			connectTargetChanged(targetID)
			if targetID != nil {
				haptics.reachedBox()
			}
		}
		if target == nil {
			feelGrid(at: point)
		} else {
			gridPoint = nil
		}

		let location = convert(point, from: content)
		dropLens.center = location
		dropLens.setShown(wouldMakeBox(from: current.source, over: targetID, at: location))

		let curve: ArrowCurve? = if let target {
			current.asConclusion
				? ArrowCurve(from: CanvasPoint(target.center), to: CanvasPoint(source))
				: ArrowCurve(from: CanvasPoint(source), to: CanvasPoint(target.center))
		} else if CanvasRect.box(at: CanvasPoint(source)).contains(CanvasPoint(point)) {
			nil
		} else if current.asConclusion {
			ArrowCurve(from: CanvasPoint(point), into: CanvasPoint(source))
		} else {
			ArrowCurve(from: CanvasPoint(source), toward: CanvasPoint(point))
		}
		current.arrow.setPath(curve?.path.cgPath ?? CGMutablePath(), animation: nil)
	}

	// MARK: - Arrows

	private func updateArrows(animation: TimeInterval?) {
		let wanted = Set(links.map(\.id))
		for (id, arrow) in arrows where !wanted.contains(id) {
			arrows[id] = nil
			arrow.removeFromSuperlayer()
		}
		for link in links {
			update(link, animation: animation)
		}
		styleArrows()
	}

	/// While a box moves, only its own arrows change
	private func updateArrows(touching id: Statement.ID, animation: TimeInterval?) {
		for link in links where link.premise == id || link.conclusion == id {
			update(link, animation: animation)
		}
	}

	private func update(_ link: Link, animation: TimeInterval?) {
		guard let source = cells[link.premise]?.center, let target = cells[link.conclusion]?.center else { return }

		let arrow: CanvasArrow
		if let existing = arrows[link.id] {
			arrow = existing
		} else {
			arrow = CanvasArrow(in: arrowLayer)
			arrows[link.id] = arrow
		}

		// A box mid-animation already has its final centre here, which is where the arrow should head too
		let path = ArrowCurve(from: CanvasPoint(source), to: CanvasPoint(target))?.path.cgPath ?? CGMutablePath()
		arrow.setPath(path, animation: animation)
	}

	private func styleArrows() {
		let accent = UIColor(Color.accentColor).resolvedColor(with: traitCollection)
		let plain = UIColor.secondaryLabel.resolvedColor(with: traitCollection)
		for (id, arrow) in arrows {
			arrow.style(isSelected: id == selectedLink, accent: accent, plain: plain)
		}
		connection?.arrow.style(isSelected: true, accent: accent, plain: plain)
	}

	// MARK: - Arrow menu

	/// A box has its own menu, so this only answers on the background, near an arrow
	func contextMenuInteraction(_: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
		guard !isReadOnly, hitTest(location, with: nil) === self, let id = LinkHitTest.link(
			near: canvasTransform.canvas(location),
			tolerance: 24 / canvasTransform.scale,
			in: links,
			positions: cells.mapValues { CanvasPoint($0.center) }
		) else {
			return nil
		}
		return UIContextMenuConfiguration(identifier: id as NSUUID, previewProvider: nil) { [weak self] _ in
			UIMenu(children: [
				UIAction(title: "Delete Arrow", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
					self?.deleteLink(id)
				},
			])
		}
	}

	func contextMenuInteraction(
		_: UIContextMenuInteraction,
		configuration _: UIContextMenuConfiguration,
		highlightPreviewForItemWithIdentifier identifier: any NSCopying
	) -> UITargetedPreview? {
		arrowPreview(identifier)
	}

	func contextMenuInteraction(
		_: UIContextMenuInteraction,
		configuration _: UIContextMenuConfiguration,
		dismissalPreviewForItemWithIdentifier identifier: any NSCopying
	) -> UITargetedPreview? {
		arrowPreview(identifier)
	}

	/// Just the arrow, drawn on its own. UIKit's preview of a view would lift the whole canvas.
	private func arrowPreview(_ identifier: any NSCopying) -> UITargetedPreview? {
		guard let id = identifier as? NSUUID, let path = arrows[id as UUID]?.path else { return nil }

		var toScreen = content.transform
		guard let onScreen = path.copy(using: &toScreen) else { return nil }
		let frame = onScreen.boundingBoxOfPath.insetBy(dx: -12, dy: -12)

		var toPreview = CGAffineTransform(translationX: -frame.minX, y: -frame.minY)
		let shape = CAShapeLayer()
		shape.path = onScreen.copy(using: &toPreview)
		shape.fillColor = nil
		shape.strokeColor = UIColor(Color.accentColor).resolvedColor(with: traitCollection).cgColor
		shape.lineWidth = 3.5
		shape.lineCap = .round

		let preview = UIView(frame: CGRect(origin: .zero, size: frame.size))
		preview.layer.addSublayer(shape)

		let parameters = UIPreviewParameters()
		parameters.backgroundColor = .clear
		return UITargetedPreview(
			view: preview,
			parameters: parameters,
			target: UIPreviewTarget(container: self, center: CGPoint(x: frame.midX, y: frame.midY))
		)
	}

	// MARK: - Pan and zoom

	@objc private func touchedDown(_ recognizer: UILongPressGestureRecognizer) {
		if recognizer.state == .began {
			touchStoppedGlide = glideLink != nil
			stopGlide()
		}
	}

	@objc private func tapped(_ recognizer: UITapGestureRecognizer) {
		guard !touchStoppedGlide else { return }
		tapBackground(canvasTransform.canvas(recognizer.location(in: self)))
	}

	@objc private func panned(_ recognizer: UIPanGestureRecognizer) {
		let travel = recognizer.translation(in: self)
		recognizer.setTranslation(.zero, in: self)

		switch recognizer.state {
			case .began, .changed:
				// A second finger makes this a pinch, which moves the canvas itself
				guard pinchRecognizer.state != .began, pinchRecognizer.state != .changed else { return }
				hasBeenMoved = true
				canvasTransform.offset.width += travel.x
				canvasTransform.offset.height += travel.y
				applyTransform()

			case .ended:
				glide(velocity: recognizer.velocity(in: self))
				updateHandles()

			case .cancelled, .failed:
				updateHandles()

			default:
				break
		}
	}

	/// Zooms about where the fingers started, and follows them if they move together
	@objc private func pinched(_ recognizer: UIPinchGestureRecognizer) {
		switch recognizer.state {
			case .began:
				stopGlide()
				hasBeenMoved = true
				pinchStart = canvasTransform
				pinchAnchor = recognizer.location(in: self)

			case .changed:
				guard recognizer.numberOfTouches >= 2 else { return }
				let location = recognizer.location(in: self)
				var transform = pinchStart.zoomed(to: pinchStart.scale * recognizer.scale, about: pinchAnchor)
				transform.offset.width += location.x - pinchAnchor.x
				transform.offset.height += location.y - pinchAnchor.y
				canvasTransform = transform
				applyTransform()

			case .ended, .cancelled, .failed:
				updateHandles()

			default:
				break
		}
	}

	// MARK: - Inertia

	/// Keeps the canvas moving at `velocity` (points per second), slowing down the way a scroll view does
	private func glide(velocity: CGSize) {
		stopGlide()

		let speed = hypot(velocity.width, velocity.height)
		guard !UIAccessibility.isReduceMotionEnabled, speed > Glide.smallestFlick else { return }

		let scale = min(speed, Glide.fastestFlick) / speed
		glideVelocity = CGSize(width: velocity.width * scale, height: velocity.height * scale)

		let link = CADisplayLink(target: self, selector: #selector(glideFrame))
		link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
		link.add(to: .main, forMode: .common)
		glideLink = link
	}

	private func glide(velocity: CGPoint) {
		glide(velocity: CGSize(width: velocity.x, height: velocity.y))
	}

	@objc private func glideFrame(_ link: CADisplayLink) {
		let seconds = link.targetTimestamp - (glideTime ?? link.timestamp)
		glideTime = link.targetTimestamp

		let slowing = exp(-Glide.friction * seconds)
		let distance = (1 - slowing) / Glide.friction
		canvasTransform.offset.width += glideVelocity.width * distance
		canvasTransform.offset.height += glideVelocity.height * distance
		applyTransform()

		glideVelocity.width *= slowing
		glideVelocity.height *= slowing
		if hypot(glideVelocity.width, glideVelocity.height) < Glide.stillSpeed {
			stopGlide()
		}
	}

	private func stopGlide() {
		guard let link = glideLink else { return }
		link.invalidate()
		glideLink = nil
		glideTime = nil
		updateHandles()
	}

	// MARK: - Gestures working together

	private var isCanvasMoving: Bool {
		if glideLink != nil {
			return true
		}
		return isRecognizing(panRecognizer) || isRecognizing(pinchRecognizer)
	}

	private func isRecognizing(_ recognizer: UIGestureRecognizer) -> Bool {
		let state = recognizer.state
		return state == .began || state == .changed
	}

	/// Panning and tapping the canvas only count on its background. `hitTest` sends a touch here when it's on nothing,
	/// or when it stops a glide, in which case a drag that follows pans the canvas even over a box.
	func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		// A box that can't be picked up shouldn't get in the way of panning
		if recognizer === panRecognizer, isReadOnly {
			return true
		}
		if recognizer === panRecognizer || recognizer === tapRecognizer {
			return touch.view === self
		}
		return true
	}

	/// One thing moves at a time: the canvas, a box, a source, or an arrow being drawn
	override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
		if recognizer === touchDownRecognizer {
			return true
		}
		if recognizer === panRecognizer || recognizer === pinchRecognizer || recognizer === tapRecognizer {
			return draggedBox == nil && draggedSource == nil && connection == nil
		}
		return !isReadOnly && !isCanvasMoving
	}

	func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
		if recognizer === touchDownRecognizer || other === touchDownRecognizer {
			return true
		}
		return (recognizer === panRecognizer && other === pinchRecognizer) || (recognizer === pinchRecognizer && other === panRecognizer)
	}
}

/// How a flick of the canvas glides to a stop
private enum Glide {
	/// Slower than this, a lift of the finger is a stop rather than a flick
	static let smallestFlick: CGFloat = 120

	/// A hard flick doesn't send the canvas further than a quick one would
	static let fastestFlick: CGFloat = 5000

	/// How quickly the glide slows: the speed falls by this fraction of itself each second, which is close to
	/// the deceleration of a scroll view
	static let friction = 2.4

	/// The glide has finished once it is slower than this, in points per second
	static let stillSpeed: CGFloat = 8
}

// MARK: - Haptics

/// What the canvas feels like, read at each tap so the Settings toggle applies at once
private final class CanvasHaptics {
	private let gridLine: UIImpactFeedbackGenerator
	private let box: UIImpactFeedbackGenerator

	init(view: UIView) {
		gridLine = UIImpactFeedbackGenerator(style: .medium, view: view)
		box = UIImpactFeedbackGenerator(style: .heavy, view: view)
	}

	func prepare() {
		guard Defaults[.hapticsEnabled] else { return }
		gridLine.prepare()
		box.prepare()
	}

	func crossedGridLine() {
		guard Defaults[.hapticsEnabled] else { return }
		gridLine.impactOccurred()
	}

	func reachedBox() {
		guard Defaults[.hapticsEnabled] else { return }
		box.impactOccurred()
	}
}

// MARK: - Hosting

/// SwiftUI for the canvas, in a hosting controller because a hosting configuration can't be told to leave the safe area
/// out. Everything here moves under the bars, and with the safe area in play its content would be laid out again on every
/// frame it's crossing them, which shows as glass moving around. Where things go is `CanvasBoardView`'s business.
private func canvasHost<Content: View>(_ content: Content) -> UIHostingController<Content> {
	let host = UIHostingController(rootView: content)
	host.safeAreaRegions = []
	host.view.backgroundColor = .clear
	host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
	return host
}

// MARK: - A box

/// Holds one box's SwiftUI. Its content is only replaced when what it shows changes.
private final class CanvasBoxCell: UIView {
	private(set) var model: CanvasBoxModel
	private let isNew: Bool
	private let hosted: UIHostingController<AnyView>

	/// Picked up by a finger
	var isLifted = false {
		didSet {
			layer.shadowOpacity = isLifted ? 0.3 : 0
		}
	}

	/// Starts at its position, so there's never a moment when it's anywhere else
	init(model: CanvasBoxModel, isNew: Bool, content: (CanvasBoxModel, _ isNew: Bool) -> AnyView) {
		self.model = model
		self.isNew = isNew
		hosted = canvasHost(content(model, isNew))
		let box = CanvasRect.box(at: model.statement.position)
		super.init(frame: CGRect(x: box.minX, y: box.minY, width: box.size.width, height: box.size.height))

		hosted.view.frame = bounds
		addSubview(hosted.view)

		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0
		layer.shadowRadius = 12
		layer.shadowOffset = CGSize(width: 0, height: 6)
		layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18).cgPath
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init(model:isNew:content:)")
	}

	func show(_ new: CanvasBoxModel, content: (CanvasBoxModel, _ isNew: Bool) -> AnyView) {
		guard new != model else { return }
		model = new
		hosted.rootView = content(new, isNew)
	}
}

// MARK: - A source

/// Holds one source's SwiftUI, the same way
private final class CanvasSourceCell: UIView {
	private(set) var model: CanvasSourceModel
	private let isNew: Bool
	private let hosted: UIHostingController<AnyView>

	/// Picked up by a finger
	var isLifted = false {
		didSet {
			layer.shadowOpacity = isLifted ? 0.3 : 0
		}
	}

	init(model: CanvasSourceModel, isNew: Bool, content: (CanvasSourceModel, _ isNew: Bool) -> AnyView) {
		self.model = model
		self.isNew = isNew
		hosted = canvasHost(content(model, isNew))
		let box = CanvasRect.box(at: model.source.position)
		super.init(frame: CGRect(x: box.minX, y: box.minY, width: box.size.width, height: box.size.height))

		hosted.view.frame = bounds
		addSubview(hosted.view)

		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0
		layer.shadowRadius = 12
		layer.shadowOffset = CGSize(width: 0, height: 6)
		layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18).cgPath
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init(model:isNew:content:)")
	}

	func show(_ new: CanvasSourceModel, content: (CanvasSourceModel, _ isNew: Bool) -> AnyView) {
		guard new != model else { return }
		model = new
		hosted.rootView = content(new, isNew)
	}
}

// MARK: - The handle

/// Holds `CanvasConnectHandle`'s SwiftUI
private final class CanvasHandleView: UIView {
	let isAbove: Bool
	private let hosted: UIHostingController<AnyView>

	init(isAbove: Bool, content: (_ pointsUp: Bool) -> AnyView) {
		self.isAbove = isAbove
		hosted = canvasHost(content(isAbove))
		let size = CanvasConnectHandle.size
		super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))

		hosted.view.frame = bounds
		addSubview(hosted.view)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init(isAbove:content:)")
	}
}

// MARK: - The lens

/// Holds `CanvasDropLens`'s SwiftUI, and grows it in and shrinks it away. Following the finger is only `center`, so
/// SwiftUI only hears about it coming and going.
private final class CanvasDropLensView: UIView {
	private let hosted = canvasHost(CanvasDropLens(isLifted: false))
	private var isShown = false

	/// Fading is all that's left under Reduce Motion
	private var hiddenTransform: CGAffineTransform {
		UIAccessibility.isReduceMotionEnabled ? .identity : CGAffineTransform(scaleX: 0.5, y: 0.5)
	}

	init() {
		super.init(frame: CGRect(origin: .zero, size: CanvasDropLens.size))
		isUserInteractionEnabled = false
		alpha = 0
		transform = hiddenTransform

		hosted.view.frame = bounds
		addSubview(hosted.view)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init()")
	}

	func setShown(_ shown: Bool) {
		guard shown != isShown else { return }
		isShown = shown
		hosted.rootView = CanvasDropLens(isLifted: shown)
		UIView.animate(springDuration: 0.35, bounce: shown ? 0.3 : 0) {
			alpha = shown ? 1 : 0
			transform = shown ? .identity : hiddenTransform
		}
	}
}

// MARK: - An arrow

/// One arrow: the line, and a wide soft stroke under it for when it's selected
private final class CanvasArrow {
	private let line = CAShapeLayer()
	private let glow = CAShapeLayer()

	init(in parent: CALayer) {
		for layer in [glow, line] {
			layer.fillColor = nil
			layer.lineCap = .round
			layer.lineJoin = .round
			parent.addSublayer(layer)
		}
		glow.lineWidth = 12
	}

	var path: CGPath? {
		line.path
	}

	func removeFromSuperlayer() {
		line.removeFromSuperlayer()
		glow.removeFromSuperlayer()
	}

	/// Slides to the new path over about `animation` seconds, or jumps to it without one
	func setPath(_ path: CGPath, animation: TimeInterval?) {
		for layer in [glow, line] {
			if let animation, let old = layer.path, old != path {
				let slide = CASpringAnimation(perceptualDuration: animation, bounce: 0)
				slide.keyPath = "path"
				slide.fromValue = old
				slide.toValue = path
				slide.duration = slide.settlingDuration
				layer.add(slide, forKey: "path")
			}
			CATransaction.begin()
			CATransaction.setDisableActions(true)
			layer.path = path
			CATransaction.commit()
		}
	}

	func style(isSelected: Bool, accent: UIColor, plain: UIColor) {
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		line.strokeColor = (isSelected ? accent : plain).cgColor
		line.lineWidth = isSelected ? 3.5 : 2.5
		glow.strokeColor = accent.withAlphaComponent(0.28).cgColor
		glow.isHidden = !isSelected
		CATransaction.commit()
	}
}
