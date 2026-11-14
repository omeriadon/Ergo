//
//  CanvasCells+AppKit.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

#if os(macOS)
	import AppKit
	import ErgoLogic
	import SwiftUI

	/// SwiftUI for the canvas. The hosting view is told to leave its size and the safe area alone: where things go and how
	/// big they are is `CanvasBoardView`'s business, and nothing on the canvas is laid out from a measured size.
	func canvasHost<Content: View>(_ content: Content) -> NSHostingView<Content> {
		let host = NSHostingView(rootView: content)
		host.sizingOptions = []
		host.safeAreaRegions = []
		host.autoresizingMask = [.width, .height]
		return host
	}

	// MARK: - A box or a source

	/// Holds one box's or source's SwiftUI. Its frame is in canvas units, since it sits in `CanvasBoardView.content`.
	class CanvasHostedCell: NSView {
		let hosted: NSHostingView<AnyView>
		private let commentTarget = CanvasClickTarget(frame: CanvasCommentLayout.frame)

		/// Its comment box was clicked
		var openComment: () -> Void = {}

		/// Being dragged
		var isLifted = false {
			didSet {
				if isLifted != oldValue {
					updateShadow()
				}
			}
		}

		/// Under the pointer, which lifts it a little
		var isHovered = false {
			didSet {
				if isHovered != oldValue {
					updateShadow()
				}
			}
		}

		/// Where it's going on the canvas. Kept rather than read from `frame`, which AppKit may still be animating, so arrows,
		/// regions and handles always aim for where the box will be, the way they do on iOS.
		private var settledCenter: CGPoint

		/// Starts at its position, so there's never a moment when it's anywhere else
		init(content: AnyView, at position: CanvasPoint, hasComment: Bool) {
			hosted = canvasHost(content)
			settledCenter = position.point
			let box = CanvasRect.box(at: position)
			super.init(frame: CGRect(x: box.minX, y: box.minY, width: box.size.width, height: box.size.height))
			wantsLayer = true

			hosted.frame = bounds
			addSubview(hosted)

			commentTarget.isHidden = !hasComment
			commentTarget.clicked = { [weak self] in self?.openComment() }
			addSubview(commentTarget)
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use init(content:at:hasComment:)")
		}

		override var isFlipped: Bool {
			true
		}

		/// Its centre on the canvas, the way the iOS cells' `center` is
		var center: CGPoint {
			get {
				settledCenter
			}
			set {
				setCenter(newValue, animated: false)
			}
		}

		/// Moves through the animator inside an animation, so it slides with whatever else that animation moves
		func setCenter(_ point: CGPoint, animated: Bool) {
			if animated {
				// Already on its way there
				guard point != settledCenter else { return }
				settledCenter = point
				animator().setFrameOrigin(origin(for: point))
			} else {
				settledCenter = point
				setFrameOrigin(origin(for: point))
			}
		}

		private func origin(for center: CGPoint) -> CGPoint {
			CGPoint(x: center.x - frame.width / 2, y: center.y - frame.height / 2)
		}

		func setHasComment(_ hasComment: Bool) {
			commentTarget.isHidden = !hasComment
		}

		/// A comment hangs outside the box, so AppKit wouldn't look there on its own
		override func hitTest(_ point: NSPoint) -> NSView? {
			let local = unsafe convert(point, from: superview)
			if !commentTarget.isHidden, commentTarget.frame.contains(local) {
				return commentTarget
			}
			return super.hitTest(point)
		}

		/// `shadow` rather than the layer's own shadow, since AppKit owns a layer-backed view's layer. It follows the box's
		/// rounded shape from what SwiftUI drew.
		private func updateShadow() {
			guard isLifted || isHovered else {
				shadow = nil
				return
			}
			let lift = NSShadow()
			lift.shadowColor = NSColor.black.withAlphaComponent(isLifted ? 0.3 : 0.12)
			lift.shadowBlurRadius = isLifted ? 12 : 6
			lift.shadowOffset = NSSize(width: 0, height: isLifted ? -6 : -2)
			shadow = lift
		}
	}

	/// A box. Its content is only replaced when what it shows changes.
	final class CanvasBoxCell: CanvasHostedCell {
		private(set) var model: CanvasBoxModel
		private let isNew: Bool

		init(model: CanvasBoxModel, isNew: Bool, content: (CanvasBoxModel, _ isNew: Bool) -> AnyView) {
			self.model = model
			self.isNew = isNew
			super.init(content: content(model, isNew), at: model.statement.position, hasComment: model.comment != nil)
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use init(model:isNew:content:)")
		}

		func show(_ new: CanvasBoxModel, content: (CanvasBoxModel, _ isNew: Bool) -> AnyView) {
			guard new != model else { return }
			model = new
			setHasComment(new.comment != nil)
			hosted.rootView = content(new, isNew)
		}
	}

	/// A source, the same way
	final class CanvasSourceCell: CanvasHostedCell {
		private(set) var model: CanvasSourceModel
		private let isNew: Bool

		init(model: CanvasSourceModel, isNew: Bool, content: (CanvasSourceModel, _ isNew: Bool) -> AnyView) {
			self.model = model
			self.isNew = isNew
			super.init(content: content(model, isNew), at: model.source.position, hasComment: model.comment != nil)
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use init(model:isNew:content:)")
		}

		func show(_ new: CanvasSourceModel, content: (CanvasSourceModel, _ isNew: Bool) -> AnyView) {
			guard new != model else { return }
			model = new
			setHasComment(new.comment != nil)
			hosted.rootView = content(new, isNew)
		}
	}

	// MARK: - Small pieces

	/// A plain clickable area, for the comment beside a box, which SwiftUI draws but can't take clicks out there
	final class CanvasClickTarget: NSView {
		var clicked: () -> Void = {}

		override var isFlipped: Bool {
			true
		}

		/// Taken so the click is this view's, rather than passed up to the canvas as a click on the background
		override func mouseDown(with _: NSEvent) {}

		override func mouseUp(with event: NSEvent) {
			if bounds.contains(convert(event.locationInWindow, from: nil)) {
				clicked()
			}
		}
	}

	/// Holds `CanvasConnectHandle`'s SwiftUI. It sits in `CanvasBoardView` itself rather than the canvas, so it stays the
	/// same size at any zoom.
	final class CanvasHandleView: NSView {
		let isAbove: Bool
		private let hosted: NSHostingView<AnyView>

		init(isAbove: Bool, content: (_ pointsUp: Bool) -> AnyView) {
			self.isAbove = isAbove
			hosted = canvasHost(content(isAbove))
			let size = CanvasConnectHandle.size
			super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
			wantsLayer = true

			hosted.frame = bounds
			addSubview(hosted)
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use init(isAbove:content:)")
		}

		override var isFlipped: Bool {
			true
		}

		var center: CGPoint {
			CGPoint(x: frame.midX, y: frame.midY)
		}

		func setCenter(_ point: CGPoint, animated: Bool) {
			let origin = CGPoint(x: point.x - frame.width / 2, y: point.y - frame.height / 2)
			if animated {
				animator().setFrameOrigin(origin)
			} else {
				setFrameOrigin(origin)
			}
		}
	}

	/// A small label on an arrow the analysis has something to say about. Clicking it opens what it wrote. Plain AppKit
	/// rather than hosted SwiftUI, since it has to follow the arrow on every frame of a drag.
	final class CanvasArrowNote: NSView {
		private static let size = CGSize(width: 92, height: 26)

		private let label = NSTextField(labelWithString: "")
		private let tapped: () -> Void
		private var tint = NSColor.controlAccentColor

		init(tapped: @escaping () -> Void) {
			self.tapped = tapped
			super.init(frame: CGRect(origin: .zero, size: Self.size))
			wantsLayer = true

			let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
			label.font = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 12) } ?? font
			label.textColor = .white
			label.alignment = .center
			label.lineBreakMode = .byTruncatingTail
			label.frame = CGRect(x: 8, y: 5, width: Self.size.width - 16, height: 16)
			addSubview(label)

			setAccessibilityElement(true)
			setAccessibilityRole(.button)
			setAccessibilityHelp("Shows what the analysis found")
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use init(tapped:)")
		}

		override var isFlipped: Bool {
			true
		}

		var center: CGPoint {
			get {
				CGPoint(x: frame.midX, y: frame.midY)
			}
			set {
				setFrameOrigin(CGPoint(x: newValue.x - frame.width / 2, y: newValue.y - frame.height / 2))
			}
		}

		func setCenter(_ point: CGPoint, animated: Bool) {
			let origin = CGPoint(x: point.x - frame.width / 2, y: point.y - frame.height / 2)
			if animated {
				animator().setFrameOrigin(origin)
			} else {
				setFrameOrigin(origin)
			}
		}

		func show(title: String, tint: NSColor) {
			label.stringValue = title
			setAccessibilityLabel(title)
			self.tint = tint
			needsDisplay = true
		}

		override var wantsUpdateLayer: Bool {
			true
		}

		/// AppKit makes the view's appearance current here, so the tint resolves for light or dark
		override func updateLayer() {
			layer?.backgroundColor = tint.cgColor
			layer?.cornerRadius = bounds.height / 2
		}

		/// The whole capsule takes the click, not the label in it
		override func hitTest(_ point: NSPoint) -> NSView? {
			frame.contains(point) ? self : nil
		}

		override func mouseDown(with _: NSEvent) {}

		override func mouseUp(with event: NSEvent) {
			if bounds.contains(convert(event.locationInWindow, from: nil)) {
				tapped()
			}
		}

		override func accessibilityPerformPress() -> Bool {
			tapped()
			return true
		}
	}
#endif
