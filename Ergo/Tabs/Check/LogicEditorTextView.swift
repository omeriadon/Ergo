import UIKit

final class LogicEditorTextView: UITextView, UIGestureRecognizerDelegate {
	var onSymbolTap: ((NSRange) -> Void)?

	func installTapHandling() {
		let tap = UITapGestureRecognizer(target: self, action: #selector(tappedEntry(_:)))
		tap.cancelsTouchesInView = false
		tap.delegate = self
		addGestureRecognizer(tap)
	}

	@objc private func tappedEntry(_ gesture: UITapGestureRecognizer) {
		let point = gesture.location(in: self)
		guard let range = characterRange(at: point), firstRect(for: range).contains(point) else { return }
		let location = offset(from: beginningOfDocument, to: range.start)
		let length = offset(from: range.start, to: range.end)
		guard length > 0, location >= 0, location + length <= (text as NSString).length else { return }
		onSymbolTap?(NSRange(location: location, length: length))
	}

	func gestureRecognizer(
		_: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
	) -> Bool {
		true
	}

	override func paste(_: Any?) {
		guard let value = UIPasteboard.general.string else { return }
		insertText(value)
	}

	override func pasteAndMatchStyle(_ sender: Any?) {
		paste(sender)
	}
}
