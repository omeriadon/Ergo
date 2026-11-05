import Defaults
import ErgoLogic
import SwiftUI
import UIKit

nonisolated struct LogicInlineSymbolAppearance {
	/// Monospaced, a step up from body, and scaled for Dynamic Type at launch
	static let baseFont = UIFontMetrics(forTextStyle: .title3).scaledFont(
		for: .monospacedSystemFont(ofSize: 20, weight: .regular)
	)

	/// The width of one space, so a comma can read as ", " without a real space in the text
	static let spaceWidth = (" " as NSString).size(withAttributes: [.font: baseFont]).width

	var font: UIFont = Self.baseFont
	var foregroundColor: UIColor = .label
	var backgroundColor: UIColor = .clear

	/// Extra room drawn after the glyph, it isn't part of the text
	var trailingSpace: CGFloat = 0

	static var `default`: Self {
		Self()
	}

	/// Customize each entry here, or supply entryAppearance to LogicTextEditor.
	static func appearance(for entry: LogicKeyboardEntry) -> Self {
		switch entry {
			case .symbol("∧"), .symbol("∨"), .symbol("→"), .symbol("↔"):
				Self(foregroundColor: .systemBlue, backgroundColor: .systemBlue.withAlphaComponent(0.08))
			case .symbol("∀"), .symbol("∃"):
				Self(foregroundColor: .systemPurple)
			case .delimiter(","):
				Self(trailingSpace: spaceWidth)
			default:
				.default
		}
	}
}

struct LogicTextEditor: UIViewRepresentable {
	@Binding var entries: [LogicKeyboardEntry]
	@Binding var isFocused: Bool
	var highlights: [LogicHighlight] = []

	/// The page's, so the letter keys can say what they stand for
	var descriptors = LogicLetters.emptyDescriptors

	var entryAppearance: (LogicKeyboardEntry) -> LogicInlineSymbolAppearance = LogicInlineSymbolAppearance.appearance
	var onEditLetters: () -> Void = {}

	@Default(.logicLetters) private var logicLetters

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeUIView(context: Context) -> LogicEditorTextView {
		let coordinator = context.coordinator
		let textView = LogicEditorTextView()
		textView.configure()
		textView.appearance = entryAppearance
		textView.letters = logicLetters

		textView.onEntriesChange = { [weak coordinator] entries in
			coordinator?.parent.entries = entries
		}

		textView.onFocusChange = { [weak coordinator] focused in
			guard let coordinator else { return }
			coordinator.lastRequestedFocus = focused
			coordinator.focusRequestID += 1
			coordinator.parent.isFocused = focused
		}

		textView.inputView = keyboard(for: textView, coordinator: coordinator)
		textView.setEntries(entries)
		textView.setHighlights(highlights)
		return textView
	}

	func updateUIView(_ uiView: LogicEditorTextView, context: Context) {
		let coordinator = context.coordinator
		coordinator.parent = self
		uiView.appearance = entryAppearance
		uiView.letters = logicLetters
		uiView.setEntries(entries)
		uiView.setHighlights(highlights)

		if let keyboardHost = coordinator.keyboardHost, keyboardHost.rootView.descriptors != descriptors {
			keyboardHost.rootView.descriptors = descriptors
		}

		guard coordinator.lastRequestedFocus != isFocused else { return }
		coordinator.lastRequestedFocus = isFocused
		coordinator.focusRequestID += 1
		let focusRequestID = coordinator.focusRequestID
		let requestedFocus = isFocused
		DispatchQueue.main.async { [weak uiView, weak coordinator] in
			guard let uiView, let coordinator,
			      coordinator.focusRequestID == focusRequestID,
			      coordinator.parent.isFocused == requestedFocus else { return }
			if requestedFocus, !uiView.isFirstResponder {
				uiView.becomeFirstResponder()
			} else if !requestedFocus, uiView.isFirstResponder {
				uiView.resignFirstResponder()
			}
		}
	}

	private func keyboard(for textView: LogicEditorTextView, coordinator: Coordinator) -> UIInputView {
		let keyboardHost = UIHostingController(
			rootView: LogicKeyboard(
				onInsert: { [weak textView] entry in
					textView?.insert(entry)
				},
				onDelete: { [weak textView] in
					textView?.deleteBackward()
				},
				onDismiss: { [weak textView] in
					textView?.resignFirstResponder()
				},
				onEditLetters: { [weak textView, weak coordinator] in
					// The keyboard goes first so it isn't fighting the sheet for the screen
					textView?.resignFirstResponder()
					coordinator?.parent.onEditLetters()
				},
				descriptors: descriptors
			)
		)
		keyboardHost.safeAreaRegions = []
		keyboardHost.view.backgroundColor = .clear
		keyboardHost.view.clipsToBounds = false
		keyboardHost.view.translatesAutoresizingMaskIntoConstraints = false

		let keyboardContainer = UIInputView(
			frame: CGRect(x: 0, y: 0, width: 0, height: 250),
			inputViewStyle: .keyboard
		)
		keyboardContainer.allowsSelfSizing = false
		keyboardContainer.clipsToBounds = false
		keyboardContainer.autoresizingMask = [.flexibleWidth]
		keyboardContainer.addSubview(keyboardHost.view)
		NSLayoutConstraint.activate([
			keyboardHost.view.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
			keyboardHost.view.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor),
			keyboardHost.view.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
			keyboardHost.view.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
		])

		coordinator.keyboardHost = keyboardHost
		return keyboardContainer
	}

	final class Coordinator {
		var parent: LogicTextEditor
		var keyboardHost: UIHostingController<LogicKeyboard>?
		var lastRequestedFocus = false
		var focusRequestID = 0

		init(_ parent: LogicTextEditor) {
			self.parent = parent
		}
	}
}
