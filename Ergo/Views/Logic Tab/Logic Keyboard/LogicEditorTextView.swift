import ErgoLogic
import UIKit

/// Holds the editor's entries and only lets in text the logic keyboard could have typed.
/// Every entry is exactly one UTF-16 unit, so text ranges and entry indices line up.
final class LogicEditorTextView: UITextView, UITextViewDelegate {
	var onEntriesChange: (([LogicKeyboardEntry]) -> Void)?
	var onFocusChange: ((Bool) -> Void)?

	var appearance: (LogicKeyboardEntry) -> LogicInlineSymbolAppearance = { _ in .default }

	/// Changing letters re-renders the same entries with the new glyphs
	var letters = LogicLetters.defaults {
		didSet {
			guard letters != oldValue else { return }
			vocabulary = LogicInputVocabulary(letters: letters)
			render()
		}
	}

	private(set) var vocabulary = LogicInputVocabulary(letters: LogicLetters.defaults)
	private(set) var entries: [LogicKeyboardEntry] = []

	private var highlights: [LogicHighlight] = []
	private var pendingEdit: NSRange?

	/// Has to go through the designated init. `init(usingTextLayoutManager:)` is an Objective-C factory
	/// that skips Swift's stored property setup, leaving `letters` and friends as zeroed memory.
	/// A nil container still gets TextKit 2.
	init() {
		super.init(frame: .zero, textContainer: nil)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure() {
		delegate = self
		autocorrectionType = .no
		spellCheckingType = .no
		inlinePredictionType = .no
		autocapitalizationType = .none
		smartQuotesType = .no
		smartDashesType = .no
		smartInsertDeleteType = .no
		writingToolsBehavior = .none
		inputAssistantItem.leadingBarButtonGroups = []
		inputAssistantItem.trailingBarButtonGroups = []
		allowsEditingTextAttributes = false
		backgroundColor = .clear
		font = LogicInlineSymbolAppearance.baseFont
		textColor = .label
		adjustsFontForContentSizeCategory = true
		textContainerInset = .zero
		textContainer.lineFragmentPadding = 0
		accessibilityLabel = "Logic editor"
		accessibilityIdentifier = "logic.logicEditor"
	}

	func setEntries(_ newEntries: [LogicKeyboardEntry]) {
		guard newEntries != entries else { return }
		entries = newEntries
		render()
	}

	/// Highlights are drawn over the normal styling, and dropped as soon as the text is edited
	func setHighlights(_ newHighlights: [LogicHighlight]) {
		guard newHighlights != highlights else { return }

		for highlight in highlights {
			style(NSRange(highlight.range))
		}

		highlights = newHighlights
		applyHighlights()
	}

	func insert(_ entry: LogicKeyboardEntry) {
		insertText(entry.glyph(letters: vocabulary.letters))
	}

	/// By whole entries, since each is one UTF-16 unit. A selection collapses to the side it's moving towards.
	func moveCursor(by offset: Int) {
		let selection = selectedRange
		let location = if selection.length > 0 {
			offset < 0 ? selection.location : NSMaxRange(selection)
		} else {
			min(max(selection.location + offset, 0), textStorage.length)
		}
		selectedRange = NSRange(location: location, length: 0)
		scrollRangeToVisible(selectedRange)
	}

	// MARK: Input

	override func insertText(_ text: String) {
		let normalized = vocabulary.normalized(text)
		guard !normalized.isEmpty else { return }
		super.insertText(normalized)
	}

	override func paste(_: Any?) {
		guard let value = UIPasteboard.general.string else { return }
		insertText(value)
	}

	override func pasteAndMatchStyle(_ sender: Any?) {
		paste(sender)
	}

	/// No IME composition, it would put unchecked text in the view
	override func setMarkedText(_: String?, selectedRange _: NSRange) {}

	override func setAttributedMarkedText(_: NSAttributedString?, selectedRange _: NSRange) {}

	func textView(
		_: UITextView,
		shouldChangeTextIn range: NSRange,
		replacementText text: String
	) -> Bool {
		guard vocabulary.accepts(text) else { return false }
		pendingEdit = NSRange(location: range.location, length: (text as NSString).length)
		return true
	}

	func textViewDidChange(_: UITextView) {
		entries = text.compactMap { vocabulary.entry(for: $0) }

		if !highlights.isEmpty {
			// The edit shifted everything, so the old ranges no longer point at the highlighted text
			highlights = []
			style(NSRange(location: 0, length: textStorage.length))
		} else if let pendingEdit {
			style(pendingEdit)
		}
		pendingEdit = nil
		onEntriesChange?(entries)
	}

	func textViewDidBeginEditing(_: UITextView) {
		onFocusChange?(true)
	}

	func textViewDidEndEditing(_: UITextView) {
		onFocusChange?(false)
	}

	// MARK: Styling

	private func render() {
		let selection = selectedRange
		let rendered = NSMutableAttributedString()
		for entry in entries {
			rendered.append(
				NSAttributedString(
					string: entry.glyph(letters: vocabulary.letters),
					attributes: attributes(for: entry)
				)
			)
		}

		attributedText = rendered
		applyHighlights()

		let length = rendered.length
		let location = min(selection.location, length)
		selectedRange = NSRange(location: location, length: min(selection.length, length - location))
		undoManager?.removeAllActions()
		resetTypingAttributes()
	}

	/// Only restyles what was just typed, so long arguments don't get slower to edit
	private func style(_ range: NSRange) {
		let storage = textStorage
		let range = NSIntersectionRange(range, NSRange(location: 0, length: storage.length))
		guard range.length > 0 else {
			resetTypingAttributes()
			return
		}

		let source = storage.string as NSString
		storage.beginEditing()
		for location in range.location ..< NSMaxRange(range) {
			let character = Character(source.substring(with: NSRange(location: location, length: 1)))
			guard let entry = vocabulary.entry(for: character) else { continue }
			storage.setAttributes(attributes(for: entry), range: NSRange(location: location, length: 1))
		}
		storage.endEditing()
		resetTypingAttributes()
	}

	private func applyHighlights() {
		let storage = textStorage
		let length = storage.length
		storage.beginEditing()
		for highlight in highlights {
			let range = NSIntersectionRange(NSRange(highlight.range), NSRange(location: 0, length: length))
			guard range.length > 0 else { continue }

			// A tint behind the glyphs, since an underline is lost under small ones like ∴
			if highlight.kind == .error {
				storage.addAttributes(
					[
						.foregroundColor: UIColor.systemRed,
						.backgroundColor: UIColor.systemRed.withAlphaComponent(0.25),
					],
					range: range
				)
			} else {
				storage.addAttribute(.backgroundColor, value: UIColor.systemOrange.withAlphaComponent(0.25), range: range)
			}
		}
		storage.endEditing()
	}

	private func attributes(for entry: LogicKeyboardEntry) -> [NSAttributedString.Key: Any] {
		let appearance = appearance(entry)
		var attributes: [NSAttributedString.Key: Any] = [
			.font: appearance.font,
			.foregroundColor: appearance.foregroundColor,
			.backgroundColor: appearance.backgroundColor,
		]

		if appearance.trailingSpace > 0 {
			attributes[.kern] = appearance.trailingSpace
		}

		return attributes
	}

	private func resetTypingAttributes() {
		typingAttributes = [
			.font: LogicInlineSymbolAppearance.baseFont,
			.foregroundColor: UIColor.label,
		]
	}
}
