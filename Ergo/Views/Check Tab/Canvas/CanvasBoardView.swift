//
//  CanvasBoardView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI
import UIKit

/// The canvas in UIKit, because following a finger through SwiftUI redraws too much for every frame. Pan, pinch, inertia,
/// dragging a box and the arrows all move layers directly, so SwiftUI isn't involved at all while something moves.
/// What a box looks like is SwiftUI, in `CanvasBox` and `StatementBoxView`.
///
/// `content` is a zero-sized view that carries the pan and zoom as its transform. Boxes sit in it at their canvas
/// positions, so moving the whole canvas is one transform however many boxes there are.
final class CanvasBoardView: UIView, UIGestureRecognizerDelegate {
	var dragStarted: (Statement.ID) -> Void = { _ in }
	var moved: (Statement.ID, CanvasPoint) -> Void = { _, _ in }
	var tapBackground: (CanvasPoint) -> Void = { _ in }
	var connectStarted: (Statement.ID) -> Void = { _ in }
	var connectTargetChanged: (Statement.ID?) -> Void = { _ in }

	/// The arrow was let go, over this box if it's over one
	var connectEnded: (Statement.ID, Statement.ID?) -> Void = { _, _ in }

	var boxContent: (CanvasBoxModel) -> any UIContentConfiguration = { _ in UIListContentConfiguration.cell() }
	var handleContent: (_ pointsUp: Bool, _ asConclusion: Bool) -> any UIContentConfiguration = { _, _ in UIListContentConfiguration.cell() }

	/// The handle was tapped, which swaps premise and conclusion for the arrow it draws
	var toggleConnectRole: () -> Void = {}

	/// Whether the selected box is the conclusion of the arrow the handle draws
	var connectsAsConclusion = false {
		didSet {
			guard connectsAsConclusion != oldValue else { return }
			handle?.show(pointsUp: handle?.pointsUp ?? false, asConclusion: connectsAsConclusion, content: handleContent)
		}
	}

	private(set) var canvasTransform = CanvasTransform()
	private(set) var hasBeenMoved = false

	private let content = UIView()
	private let arrowLayer = CALayer()

	private var cells: [Statement.ID: CanvasBoxCell] = [:]
	private var arrows: [Link.ID: CanvasArrow] = [:]
	private var links: [Link] = []
	private var selectedStatement: Statement.ID?
	private var selectedLink: Link.ID?

	private var handle: CanvasHandleView?

	/// The box the handle's side was picked for, so it keeps that side for as long as the box stays selected
	private var handleSideFor: Statement.ID?

	/// An arrow being dragged out of the handle
	private var connection: (source: Statement.ID, target: Statement.ID?, arrow: CanvasArrow)?

	private lazy var panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned))
	private lazy var pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
	private lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
	private lazy var touchDownRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(touchedDown))

	/// A box under the finger, and where it was picked up
	private var draggedBox: (id: Statement.ID, origin: CGPoint)?

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

		registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _) in
			view.styleArrows()
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
		if let handle, handle.alpha > 0.5, let hit = handle.hitTest(convert(point, to: handle), with: event) {
			return hit
		}
		for cell in content.subviews.reversed() {
			if let hit = cell.hitTest(convert(point, to: cell), with: event) {
				return hit
			}
		}
		return self
	}

	// MARK: - From SwiftUI

	func update(
		boxes: [CanvasBoxModel],
		links: [Link],
		selectedStatement: Statement.ID?,
		selectedLink: Link.ID?,
		animated: Bool
	) {
		let wanted = Set(boxes.map(\.statement.id))
		for (id, cell) in cells where !wanted.contains(id) {
			cells[id] = nil
			remove(cell, animated: animated)
		}

		for model in boxes {
			let id = model.statement.id
			let cell = cells[id] ?? addCell(for: model)
			cell.show(model, content: boxContent)
			if draggedBox?.id != id {
				cell.center = model.statement.position.point
			}
			cell.alpha = 1
		}

		if let selectedStatement, draggedBox == nil, let cell = cells[selectedStatement] {
			content.bringSubviewToFront(cell)
		}

		self.links = links
		self.selectedStatement = selectedStatement
		self.selectedLink = selectedLink
		updateArrows(animation: animated ? 0.5 : nil)
		updateHandle()
	}

	func move(to transform: CanvasTransform, animation: Animation?) {
		stopGlide()
		canvasTransform = transform
		if let animation {
			UIView.animate(animation) {
				applyTransform()
				updateHandle()
			}
		} else {
			applyTransform()
			updateHandle()
		}
	}

	private func applyTransform() {
		content.transform = CGAffineTransform(
			a: canvasTransform.scale, b: 0,
			c: 0, d: canvasTransform.scale,
			tx: canvasTransform.offset.width, ty: canvasTransform.offset.height
		)
		positionHandle()
	}

	// MARK: - Boxes

	private func addCell(for model: CanvasBoxModel) -> CanvasBoxCell {
		let cell = CanvasBoxCell(model: model, content: boxContent)
		UIView.performWithoutAnimation {
			cell.center = model.statement.position.point
			cell.alpha = 0
			content.addSubview(cell)
		}

		let drag = UIPanGestureRecognizer(target: self, action: #selector(boxPanned))
		drag.maximumNumberOfTouches = 1
		drag.delegate = self
		cell.addGestureRecognizer(drag)

		cells[model.statement.id] = cell
		return cell
	}

	private func remove(_ cell: CanvasBoxCell, animated: Bool) {
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
				updateHandle()
				dragStarted(id)

			case .changed:
				guard let draggedBox, draggedBox.id == id else { return }
				let travel = recognizer.translation(in: content)
				cell.center = CGPoint(x: draggedBox.origin.x + travel.x, y: draggedBox.origin.y + travel.y)
				updateArrows(touching: id, animation: nil)

			case .ended, .cancelled, .failed:
				guard let draggedBox, draggedBox.id == id else { return }
				self.draggedBox = nil
				cell.isLifted = false

				let finished = recognizer.state == .ended
				let target = finished ? CanvasGrid.snapped(CanvasPoint(cell.center)) : CanvasPoint(draggedBox.origin)
				UIView.animate(springDuration: 0.25, bounce: 0) {
					cell.center = target.point
					updateHandle()
				}
				updateArrows(touching: id, animation: 0.25)
				if finished {
					moved(id, target)
				}

			default:
				break
		}
	}

	// MARK: - Connecting

	/// Shows the handle on the selected box, on the side with more room, judged when the box is selected.
	/// It stays on that side however the canvas moves, and only picks again for another box.
	private func updateHandle() {
		guard let id = selectedStatement, let box = cells[id], cells.count > 1, draggedBox == nil, connection == nil else {
			if selectedStatement == nil {
				handleSideFor = nil
			}
			if let handle, handle.alpha > 0 {
				UIView.animate(withDuration: 0.12) {
					handle.alpha = 0
				}
			}
			return
		}

		let handle = handle ?? makeHandle()
		if handleSideFor != id {
			handleSideFor = id
			let up = canvasTransform.screen(CanvasPoint(box.center)).y > bounds.midY
			handle.show(pointsUp: up, asConclusion: connectsAsConclusion, content: handleContent)
		}

		if handle.alpha == 0 {
			UIView.performWithoutAnimation {
				positionHandle()
			}
		} else {
			positionHandle()
		}
		UIView.animate(withDuration: 0.12) {
			handle.alpha = 1
		}
	}

	private func positionHandle() {
		guard let handle, let id = selectedStatement, let box = cells[id] else { return }
		let center = canvasTransform.screen(CanvasPoint(box.center))
		let reach = CanvasLayout.boxSize.height / 2 * canvasTransform.scale + 8 + CanvasConnectHandle.size / 2
		handle.center = CGPoint(x: center.x, y: center.y + (handle.pointsUp ? -reach : reach))
	}

	private func makeHandle() -> CanvasHandleView {
		let handle = CanvasHandleView(content: handleContent)
		handle.alpha = 0

		let drag = UIPanGestureRecognizer(target: self, action: #selector(handlePanned))
		drag.maximumNumberOfTouches = 1
		drag.delegate = self
		handle.addGestureRecognizer(drag)

		let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapped))
		tap.delegate = self
		handle.addGestureRecognizer(tap)

		addSubview(handle)
		self.handle = handle
		return handle
	}

	@objc private func handleTapped() {
		toggleConnectRole()
	}

	@objc private func handlePanned(_ recognizer: UIPanGestureRecognizer) {
		switch recognizer.state {
			case .began:
				guard let source = selectedStatement else { return }
				let arrow = CanvasArrow(in: arrowLayer)
				connection = (source, nil, arrow)
				styleArrows()
				updateHandle()
				connectStarted(source)
				followConnection(to: recognizer.location(in: content))

			case .changed:
				followConnection(to: recognizer.location(in: content))

			case .ended, .cancelled, .failed:
				guard let finished = connection else { return }
				connection = nil
				finished.arrow.removeFromSuperlayer()
				updateHandle()
				connectEnded(finished.source, recognizer.state == .ended ? finished.target : nil)

			default:
				break
		}
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
		}

		let curve: ArrowCurve? = if let target {
			connectsAsConclusion
				? ArrowCurve(from: CanvasPoint(target.center), to: CanvasPoint(source))
				: ArrowCurve(from: CanvasPoint(source), to: CanvasPoint(target.center))
		} else if CanvasRect.box(at: CanvasPoint(source)).contains(CanvasPoint(point)) {
			nil
		} else if connectsAsConclusion {
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
				updateHandle()

			case .cancelled, .failed:
				updateHandle()

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
				updateHandle()

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
		updateHandle()
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
		if recognizer === panRecognizer || recognizer === tapRecognizer {
			return touch.view === self
		}
		return true
	}

	/// One thing moves at a time: the canvas, a box, or an arrow being drawn
	override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
		if recognizer === touchDownRecognizer {
			return true
		}
		if recognizer === panRecognizer || recognizer === pinchRecognizer || recognizer === tapRecognizer {
			return draggedBox == nil && connection == nil
		}
		return !isCanvasMoving
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

// MARK: - A box

/// Holds one box's SwiftUI. Its content is only replaced when what it shows changes.
private final class CanvasBoxCell: UIView {
	private(set) var model: CanvasBoxModel
	private let hosted: any UIView & UIContentView

	/// Picked up by a finger
	var isLifted = false {
		didSet {
			layer.shadowOpacity = isLifted ? 0.3 : 0
		}
	}

	init(model: CanvasBoxModel, content: (CanvasBoxModel) -> any UIContentConfiguration) {
		self.model = model
		hosted = content(model).makeContentView()
		let size = CanvasLayout.boxSize
		super.init(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))

		hosted.frame = bounds
		hosted.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		addSubview(hosted)

		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0
		layer.shadowRadius = 12
		layer.shadowOffset = CGSize(width: 0, height: 6)
		layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18).cgPath
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init(model:content:)")
	}

	func show(_ new: CanvasBoxModel, content: (CanvasBoxModel) -> any UIContentConfiguration) {
		guard new != model else { return }
		model = new
		hosted.configuration = content(new)
	}
}

// MARK: - The handle

/// Holds `CanvasConnectHandle`'s SwiftUI
private final class CanvasHandleView: UIView {
	private(set) var pointsUp = false
	private var asConclusion = false
	private let hosted: any UIView & UIContentView

	init(content: (_ pointsUp: Bool, _ asConclusion: Bool) -> any UIContentConfiguration) {
		hosted = content(pointsUp, asConclusion).makeContentView()
		let size = CanvasConnectHandle.size
		super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))

		hosted.frame = bounds
		hosted.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		addSubview(hosted)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init(content:)")
	}

	func show(pointsUp newSide: Bool, asConclusion newRole: Bool, content: (_ pointsUp: Bool, _ asConclusion: Bool) -> any UIContentConfiguration) {
		guard newSide != pointsUp || newRole != asConclusion else { return }
		pointsUp = newSide
		asConclusion = newRole
		hosted.configuration = content(newSide, newRole)
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
