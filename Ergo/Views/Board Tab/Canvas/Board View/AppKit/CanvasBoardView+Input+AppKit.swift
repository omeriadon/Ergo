//
//  CanvasBoardView+Input+AppKit.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

#if os(macOS)
	import AppKit
	import ErgoLogic
	import ErgoSync
	import SwiftUI

	/// The Mac's ways of moving around the canvas, in place of the iOS fingers: the trackpad and the mouse wheel pan, pinching
	/// or ⌘ with the wheel zooms, the pointer hovers, right-click opens menus, and keys work once the canvas has been clicked.
	extension CanvasBoardView {
		// MARK: - Clicking and dragging the background

		override func mouseDown(with event: NSEvent) {
			// Control-click is a right-click on a Mac
			if event.modifierFlags.contains(.control) {
				if let menu = menu(for: event) {
					NSMenu.popUpContextMenu(menu, with: event, for: self)
				}
				return
			}
			let location = convert(event.locationInWindow, from: nil)
			// A click SwiftUI didn't want can still reach here from a box, up the responder chain. Only the background counts.
			guard hitView(at: location) === self else {
				super.mouseDown(with: event)
				return
			}
			unsafe window?.makeFirstResponder(self)
			backgroundPress = (location, location, false)
		}

		/// Dragging empty canvas moves it, without gliding on afterwards: on a Mac, coasting comes from the trackpad's own
		/// momentum, through `scrollWheel`
		override func mouseDragged(with event: NSEvent) {
			guard var press = backgroundPress else {
				super.mouseDragged(with: event)
				return
			}
			let location = convert(event.locationInWindow, from: nil)
			if !press.isPanning {
				// A little wobble during a click is still a click
				guard hypot(location.x - press.start.x, location.y - press.start.y) >= Pointer.dragDistance else { return }
				press.isPanning = true
				NSCursor.closedHand.set()
			}
			pan(by: CGSize(width: location.x - press.last.x, height: location.y - press.last.y))
			press.last = location
			backgroundPress = press
		}

		override func mouseUp(with event: NSEvent) {
			guard let press = backgroundPress else {
				super.mouseUp(with: event)
				return
			}
			backgroundPress = nil
			if press.isPanning {
				updateHandles()
				updateHover(at: convert(event.locationInWindow, from: nil))
			} else {
				tapBackground(canvasTransform.canvas(press.start))
			}
		}

		// MARK: - Scrolling and zooming

		/// Two fingers on a trackpad pan, and keep going with the system's momentum once they lift, which arrives here as more
		/// scrolling. A mouse wheel pans up and down, or sideways with Shift. ⌘ with either zooms about the pointer.
		override func scrollWheel(with event: NSEvent) {
			// What's being dragged stays under the pointer, so the canvas holds still beneath it
			guard draggedBox == nil, draggedSource == nil, connection == nil, backgroundPress?.isPanning != true else { return }
			let location = convert(event.locationInWindow, from: nil)

			if event.modifierFlags.contains(.command) {
				let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * Pointer.lineHeight
				zoom(by: exp(delta * Pointer.zoomPerPoint), about: location)
				return
			}

			var horizontal = event.scrollingDeltaX
			var vertical = event.scrollingDeltaY
			if !event.hasPreciseScrollingDeltas {
				// A wheel counts in lines. Shift turns it sideways, which AppKit has usually done already.
				if event.modifierFlags.contains(.shift), horizontal == 0 {
					horizontal = vertical
					vertical = 0
				}
				horizontal *= Pointer.lineHeight
				vertical *= Pointer.lineHeight
			}
			guard horizontal != 0 || vertical != 0 else { return }
			// The deltas already follow the person's natural scrolling setting, so the canvas moves with them as it is
			pan(by: CGSize(width: horizontal, height: vertical))
			updateHover(at: location)
		}

		/// A trackpad pinch, zooming about the pointer
		override func magnify(with event: NSEvent) {
			guard draggedBox == nil, draggedSource == nil, connection == nil else { return }
			zoom(by: max(1 + event.magnification, 0.1), about: convert(event.locationInWindow, from: nil))
		}

		/// A two-finger double tap goes to actual size, or closer in when it's already there
		override func smartMagnify(with event: NSEvent) {
			let location = convert(event.locationInWindow, from: nil)
			let target: CGFloat = abs(canvasTransform.scale - 1) < 0.01 ? Pointer.closeZoom : 1
			zoom(by: target / canvasTransform.scale, about: location, animation: .smooth)
		}

		// MARK: - Hovering

		override func mouseMoved(with event: NSEvent) {
			updateHover(at: convert(event.locationInWindow, from: nil))
		}

		override func mouseExited(with _: NSEvent) {
			guard draggedBox == nil, draggedSource == nil, connection == nil else { return }
			setHover(cell: nil, link: nil)
			NSCursor.arrow.set()
		}

		/// What's under the pointer at `location`, in this view's points: a box or source gets lifted a little and a box gets
		/// the handles, and an arrow near the pointer on the background is drawn stronger
		func updateHover(at location: CGPoint) {
			guard draggedBox == nil, draggedSource == nil, connection == nil, backgroundPress?.isPanning != true else { return }

			let hit = hitView(at: location)
			var cell = hostedCell(containing: hit)
			// Keep the box while the pointer crosses the gap to one of its handles, or they'd go as it reached them
			if cell == nil, let hoveredCell, hoveredCell is CanvasBoxCell, handleReach(of: hoveredCell).contains(location) {
				cell = hoveredCell
			}
			let link = hit === self ? link(near: location) : nil
			setHover(cell: cell, link: link)
			updateCursor(at: location)
		}

		func setHover(cell: CanvasHostedCell?, link: Link.ID?) {
			if cell !== hoveredCell {
				hoveredCell?.isHovered = false
				cell?.isHovered = true
				hoveredCell = cell
			}
			let statement = (cell as? CanvasBoxCell)?.model.statement.id
			if statement != hoveredStatement {
				hoveredStatement = statement
				updateHandles()
			}
			if link != hoveredLink {
				hoveredLink = link
				styleArrows()
			}
		}

		/// A box with room above and below it for its handles, in this view's points
		func handleReach(of cell: CanvasHostedCell) -> CGRect {
			convert(cell.frame, from: content).insetBy(dx: 0, dy: -(8 + CanvasConnectHandle.size))
		}

		/// The box or source a view is part of, if it's in one
		func hostedCell(containing view: NSView) -> CanvasHostedCell? {
			var current: NSView? = view
			while let view = current, view !== content, view !== self {
				if let cell = view as? CanvasHostedCell {
					return cell
				}
				current = unsafe view.superview
			}
			return nil
		}

		/// Whether a view is one of the handles or inside one
		func isHandle(_ view: NSView) -> Bool {
			var current: NSView? = view
			while let view = current, view !== self {
				if view is CanvasHandleView {
					return true
				}
				current = unsafe view.superview
			}
			return false
		}

		/// A hand over what can be dragged, a crosshair over the handles, and a pointing hand over what opens something
		func updateCursor(at location: CGPoint) {
			let hit = hitView(at: location)
			let cursor: NSCursor = if hit is CanvasArrowNote || hit is CanvasClickTarget {
				.pointingHand
			} else if isHandle(hit) {
				.crosshair
			} else if hostedCell(containing: hit) != nil {
				isReadOnly ? .arrow : .openHand
			} else if hit === self, hoveredLink != nil {
				.pointingHand
			} else {
				.arrow
			}
			cursor.set()
		}

		// MARK: - Menus

		/// A box and a source have their own SwiftUI menus, so this only answers on the background, near an arrow
		override func menu(for event: NSEvent) -> NSMenu? {
			let location = convert(event.locationInWindow, from: nil)
			guard !isReadOnly, hitView(at: location) === self, let id = link(near: location) else { return nil }

			let menu = NSMenu()
			if strengths[id] != nil || notedLinks.contains(id) {
				menu.addItem(canvasMenuItem(title: "Show Analysis", symbol: "text.magnifyingglass") { [weak self] in
					self?.showAnalysis(.link(id))
				})
			}
			menu.addItem(canvasMenuItem(title: "Delete Arrow", symbol: "trash") { [weak self] in
				self?.deleteLink(id)
			})
			return menu
		}

		// MARK: - Keys

		/// Delete removes what's selected, Return opens it, and the arrow keys move the canvas (further with Shift)
		override func keyDown(with event: NSEvent) {
			guard let key = event.specialKey else {
				super.keyDown(with: event)
				return
			}
			let step = event.modifierFlags.contains(.shift) ? Pointer.keyStep * 4 : Pointer.keyStep
			switch key {
				case .delete, .deleteForward, .backspace:
					if deleteSelection() {
						return
					}
				case .carriageReturn, .enter:
					if openSelection() {
						return
					}
				case .leftArrow:
					pan(by: CGSize(width: step, height: 0))
					return
				case .rightArrow:
					pan(by: CGSize(width: -step, height: 0))
					return
				case .upArrow:
					pan(by: CGSize(width: 0, height: step))
					return
				case .downArrow:
					pan(by: CGSize(width: 0, height: -step))
					return
				default:
					break
			}
			super.keyDown(with: event)
		}

		/// ⌘+ and ⌘- zoom about the middle of the canvas, and ⌘0 goes back to actual size. Key equivalents come here before
		/// `keyDown`, and a menu could take them first, so these only answer while the canvas is first responder.
		override func performKeyEquivalent(with event: NSEvent) -> Bool {
			let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
			guard unsafe window?.firstResponder === self, modifiers == .command || modifiers == [.command, .shift] else {
				return super.performKeyEquivalent(with: event)
			}
			let middle = CGPoint(x: bounds.midX, y: bounds.midY)
			switch event.charactersIgnoringModifiers ?? "" {
				case "=", "+":
					zoom(by: Pointer.keyZoom, about: middle, animation: .smooth)
					return true
				case "-":
					zoom(by: 1 / Pointer.keyZoom, about: middle, animation: .smooth)
					return true
				case "0":
					zoom(by: 1 / canvasTransform.scale, about: middle, animation: .smooth)
					return true
				default:
					return super.performKeyEquivalent(with: event)
			}
		}

		/// What a box's or source's own Delete does, or the selected arrow going. Nothing on a board that can only be viewed.
		func deleteSelection() -> Bool {
			guard !isReadOnly else { return false }
			if let selectedLink {
				deleteLink(selectedLink)
				return true
			}
			if let id = selectedStatement, let cell = cells[id], let actions = boxActions?(cell.model.statement) {
				actions.delete()
				return true
			}
			if let id = selectedSource, let cell = sourceCells[id], let actions = sourceActions?(cell.model.source) {
				actions.delete()
				return true
			}
			return false
		}

		/// What double-clicking the selected box or source does
		func openSelection() -> Bool {
			if let id = selectedStatement, let cell = cells[id], let actions = boxActions?(cell.model.statement) {
				actions.edit()
				return true
			}
			if let id = selectedSource, let cell = sourceCells[id], let actions = sourceActions?(cell.model.source) {
				actions.open()
				return true
			}
			return false
		}
	}

	/// A menu item that runs a closure, since `NSMenuItem` otherwise wants a target and a selector. The target is kept as
	/// the item's `representedObject`, since a menu item doesn't keep its target.
	@MainActor
	func canvasMenuItem(title: String, symbol: String, handler: @escaping () -> Void) -> NSMenuItem {
		let action = CanvasMenuAction(handler: handler)
		let item = NSMenuItem(title: title, action: #selector(CanvasMenuAction.run), keyEquivalent: "")
		item.target = action
		item.representedObject = action
		item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
		return item
	}

	final class CanvasMenuAction: NSObject {
		private let handler: () -> Void

		init(handler: @escaping () -> Void) {
			self.handler = handler
		}

		@objc func run() {
			handler()
		}
	}

	/// How the pointer, the wheel and the keys move the canvas
	private enum Pointer {
		/// How far a press on the background moves, in points, before it's a drag rather than a click
		static let dragDistance: CGFloat = 3

		/// Points a mouse wheel's line is worth
		static let lineHeight: CGFloat = 10

		/// How much ⌘-scrolling zooms for each point scrolled: the scale changes by e to this power
		static let zoomPerPoint: CGFloat = 0.01

		/// Points an arrow key moves the canvas
		static let keyStep: CGFloat = 40

		/// How much ⌘+ and ⌘- zoom each time
		static let keyZoom: CGFloat = 1.25

		/// Where a two-finger double tap goes from actual size
		static let closeZoom: CGFloat = 1.5
	}
#endif
