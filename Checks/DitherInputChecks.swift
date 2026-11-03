import CoreGraphics

// Run in the context of DitherView.swift, or append to the input storage declaration.
import Foundation

@main
struct DitherInputChecks {
	@MainActor
	static func main() {
		let storage = DitherInputStorage()
		precondition(storage.location == nil)
		storage.setHoverLocation(CGPoint(x: 1, y: 2))
		precondition(storage.location == CGPoint(x: 1, y: 2))
		storage.setDragLocation(CGPoint(x: 3, y: 4))
		storage.setHoverLocation(CGPoint(x: 5, y: 6))
		precondition(storage.location == CGPoint(x: 3, y: 4))
		storage.setDragLocation(nil)
		precondition(storage.location == CGPoint(x: 5, y: 6))
		storage.clear()
		precondition(storage.hoverLocation == nil && storage.dragLocation == nil)
		precondition(storage.location == nil)
		print("Dither input checks passed: drag priority, hover fallback, and lifecycle cleanup.")
	}
}
