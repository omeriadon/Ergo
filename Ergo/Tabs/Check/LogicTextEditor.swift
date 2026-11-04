import Defaults
import SwiftUI
import UIKit

struct LogicInlineSymbolAppearance {
	var font: UIFont = .preferredFont(forTextStyle: .body)
	var foregroundColor: UIColor = .label
	var backgroundColor: UIColor = .clear

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
			default:
				.default
		}
	}
}

struct LogicTextEditor: UIViewRepresentable {
	@Binding var text: String
	@Binding var isFocused: Bool
	let symbolDefinitions: [LogicEditorSymbolDefinition]
	@Default(.logicLetters) var logicLetters
	var entryAppearance: (LogicKeyboardEntry) -> LogicInlineSymbolAppearance

	init(
		text: Binding<String>,
		isFocused: Binding<Bool>,
		symbolDefinitions: [LogicEditorSymbolDefinition] = [],
		entryAppearance: @escaping (LogicKeyboardEntry) -> LogicInlineSymbolAppearance
	) {
		_text = text
		_isFocused = isFocused
		self.symbolDefinitions = symbolDefinitions
		self.entryAppearance = entryAppearance
	}

	@MainActor
	init(
		text: Binding<String>,
		isFocused: Binding<Bool>,
		symbolDefinitions: [LogicEditorSymbolDefinition] = []
	) {
		self.init(
			text: text,
			isFocused: isFocused,
			symbolDefinitions: symbolDefinitions,
			entryAppearance: LogicInlineSymbolAppearance.appearance
		)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeUIView(context: Context) -> LogicEditorTextView {
		let textView = LogicEditorTextView(usingTextLayoutManager: true)
		textView.delegate = context.coordinator
		textView.onSymbolTap = { [weak coordinator = context.coordinator, weak textView] range in
			guard let textView else { return }
			coordinator?.presentEntry(in: textView, range: range)
		}
		textView.installTapHandling()
		textView.autocorrectionType = .no
		textView.spellCheckingType = .no
		textView.inlinePredictionType = .no
		textView.autocapitalizationType = .none
		textView.inputAssistantItem.leadingBarButtonGroups = []
		textView.inputAssistantItem.trailingBarButtonGroups = []
		textView.backgroundColor = .clear
		textView.font = .preferredFont(forTextStyle: .body)
		textView.textColor = .label
		textView.adjustsFontForContentSizeCategory = true
		textView.textContainerInset = .zero
		textView.textContainer.lineFragmentPadding = 0
		textView.allowsEditingTextAttributes = false
		textView.accessibilityLabel = "Logic editor"
		textView.accessibilityIdentifier = "check.logicEditor"

		let keyboardHost = UIHostingController(
			rootView: LogicKeyboard(
				onInsert: { [weak textView] value in
					textView?.insertText(value)
				},
				onDelete: { [weak textView] in
					textView?.deleteBackward()
				},
				onDismiss: { [weak textView] in
					textView?.resignFirstResponder()
				}
			)
		)
		keyboardHost.safeAreaRegions = []
		keyboardHost.view.backgroundColor = .clear
		keyboardHost.view.translatesAutoresizingMaskIntoConstraints = false
		let keyboardContainer = UIInputView(
			frame: CGRect(x: 0, y: 0, width: 0, height: 250),
			inputViewStyle: .keyboard
		)
		keyboardContainer.allowsSelfSizing = false
		keyboardContainer.autoresizingMask = [.flexibleWidth]
		keyboardContainer.addSubview(keyboardHost.view)
		NSLayoutConstraint.activate([
			keyboardHost.view.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
			keyboardHost.view.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor),
			keyboardHost.view.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
			keyboardHost.view.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
		])
		context.coordinator.keyboardHost = keyboardHost
		textView.inputView = keyboardContainer
		if context.coordinator.vocabulary.accepts(text) {
			textView.text = text
		} else {
			context.coordinator.rejectBinding(text, preserving: "")
		}
		context.coordinator.style(textView)
		return textView
	}

	func updateUIView(_ uiView: LogicEditorTextView, context: Context) {
		let coordinator = context.coordinator
		coordinator.parent = self
		coordinator.vocabulary = LogicInputVocabulary(logicLetters: logicLetters)
		if uiView.text != text {
			if coordinator.vocabulary.accepts(text) {
				let selection = uiView.selectedRange
				uiView.text = text
				let length = (text as NSString).length
				let location = min(selection.location, length)
				uiView.selectedRange = NSRange(location: location, length: min(selection.length, length - location))
				uiView.undoManager?.removeAllActions()
			} else {
				coordinator.rejectBinding(text, preserving: uiView.text)
			}
		}
		coordinator.style(uiView)
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

	final class Coordinator: NSObject, UITextViewDelegate, UIPopoverPresentationControllerDelegate {
		var parent: LogicTextEditor
		var keyboardHost: UIHostingController<LogicKeyboard>?
		var vocabulary: LogicInputVocabulary
		var lastRequestedFocus = false
		var focusRequestID = 0
		weak var presentedDetail: UIViewController?

		init(_ parent: LogicTextEditor) {
			self.parent = parent
			vocabulary = LogicInputVocabulary(logicLetters: parent.logicLetters)
		}

		func rejectBinding(_ rejected: String, preserving previous: String) {
			DispatchQueue.main.async { [weak self] in
				guard let self, parent.text == rejected else { return }
				parent.text = previous
			}
		}

		func textView(
			_: UITextView,
			shouldChangeTextIn _: NSRange,
			replacementText: String
		) -> Bool {
			vocabulary.accepts(replacementText)
		}

		func textViewDidChange(_ textView: UITextView) {
			style(textView)
			parent.text = textView.text
		}

		func style(_ textView: UITextView) {
			let source = textView.text ?? ""
			let storage = textView.textStorage
			storage.beginEditing()
			defer { storage.endEditing() }
			var location = 0
			for character in source {
				let glyph = String(character)
				let entry = vocabulary.entry(for: glyph) ?? .variable(glyph)
				let appearance = parent.entryAppearance(entry)
				let range = NSRange(location: location, length: (glyph as NSString).length)
				let attributes: [NSAttributedString.Key: Any] = [
					.font: appearance.font,
					.foregroundColor: appearance.foregroundColor,
					.backgroundColor: appearance.backgroundColor,
				]
				if !NSDictionary(dictionary: storage.attributes(at: location, effectiveRange: nil)).isEqual(to: attributes) {
					storage.setAttributes(attributes, range: range)
				}
				location += range.length
			}
			textView.typingAttributes = [
				.font: UIFont.preferredFont(forTextStyle: .body),
				.foregroundColor: UIColor.label,
			]
		}

		func presentEntry(in textView: UITextView, range: NSRange) {
			guard presentedDetail == nil else { return }
			let glyph = (textView.text as NSString).substring(with: range)
			guard let entry = vocabulary.entry(for: glyph), glyph != "\n" else { return }
			let definition = entry.isLetter ? nil : parent.symbolDefinitions.first { $0.glyph == glyph }
			let title = definition?.name ?? (entry.isLetter ? "Variable \(glyph)" : glyph)
			let detail = UIHostingController(rootView: LogicSymbolPopover(title: title, summary: definition?.summary ?? ""))
			detail.sizingOptions = .preferredContentSize
			detail.modalPresentationStyle = .popover
			guard let popover = detail.popoverPresentationController,
			      let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
			      let end = textView.position(from: start, offset: range.length),
			      let textRange = textView.textRange(from: start, to: end) else { return }
			popover.sourceView = textView
			popover.sourceRect = textView.firstRect(for: textRange)
			popover.permittedArrowDirections = [.up, .down]
			popover.delegate = self
			var responder: UIResponder? = textView
			while let current = responder, !(current is UIViewController) {
				responder = current.next
			}
			guard let presenter = responder as? UIViewController, presenter.presentedViewController == nil else { return }
			presentedDetail = detail
			presenter.present(detail, animated: true)
		}

		func adaptivePresentationStyle(for _: UIPresentationController) -> UIModalPresentationStyle {
			.none
		}

		func textViewDidBeginEditing(_: UITextView) {
			lastRequestedFocus = true
			focusRequestID += 1
			parent.isFocused = true
		}

		func textViewDidEndEditing(_: UITextView) {
			lastRequestedFocus = false
			focusRequestID += 1
			parent.isFocused = false
		}
	}
}

private struct LogicSymbolPopover: View {
	let title: String
	let summary: String

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.headline)
			if !summary.isEmpty {
				Text(summary)
					.foregroundStyle(.secondary)
			}
		}
		.padding()
		.frame(idealWidth: 260, maxWidth: 320, alignment: .leading)
		.fixedSize(horizontal: false, vertical: true)
		.accessibilityIdentifier("check.logicSymbolDetails")
	}
}
