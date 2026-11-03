//
//  LogicTextEditor.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import SwiftUI
import UIKit

struct LogicTextEditor: UIViewRepresentable {
	@Binding var text: String
	@Binding var isFocused: Bool

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeUIView(context: Context) -> UITextView {
		let textView = UITextView()

		textView.autocorrectionType = .no
		textView.spellCheckingType = .no
		textView.inlinePredictionType = .no
		textView.autocapitalizationType = .none

		textView.inputAssistantItem.leadingBarButtonGroups = []
		textView.inputAssistantItem.trailingBarButtonGroups = []

		textView.delegate = context.coordinator
		textView.text = text
		textView.backgroundColor = .clear
		textView.font = .preferredFont(forTextStyle: .body)
		textView.textColor = .label
		textView.adjustsFontForContentSizeCategory = true

		textView.textContainerInset = .zero
		textView.textContainer.lineFragmentPadding = 0

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
		keyboardHost.view.backgroundColor = .clear

		let keyboardContainer = UIInputView(
			frame: CGRect(x: 0, y: 0, width: 0, height: 250),
			inputViewStyle: .keyboard
		)

		keyboardContainer.autoresizingMask = [.flexibleWidth]
		keyboardContainer.allowsSelfSizing = false

		keyboardHost.view.translatesAutoresizingMaskIntoConstraints = false
		keyboardContainer.addSubview(keyboardHost.view)

		NSLayoutConstraint.activate([
			keyboardHost.view.topAnchor.constraint(
				equalTo: keyboardContainer.topAnchor
			),
			keyboardHost.view.bottomAnchor.constraint(
				equalTo: keyboardContainer.bottomAnchor
			),
			keyboardHost.view.leadingAnchor.constraint(
				equalTo: keyboardContainer.leadingAnchor
			),
			keyboardHost.view.trailingAnchor.constraint(
				equalTo: keyboardContainer.trailingAnchor
			),
		])

		context.coordinator.keyboardHost = keyboardHost
		textView.inputView = keyboardContainer

		textView.accessibilityLabel = "Logic editor"
		textView.accessibilityIdentifier = "check.logicEditor"

		return textView
	}

	func updateUIView(_ uiView: UITextView, context: Context) {
		let coordinator = context.coordinator
		coordinator.parent = self
		coordinator.isUpdating = true

		defer {
			coordinator.isUpdating = false
		}

		// Synchronise text
		if uiView.text != text {
			let selection = uiView.selectedRange

			uiView.text = text

			let length = (text as NSString).length
			let location = min(selection.location, length)

			uiView.selectedRange = NSRange(
				location: location,
				length: min(selection.length, length - location)
			)
		}

		// Only respond to actual focus-state changes
		guard coordinator.lastRequestedFocus != isFocused else {
			return
		}

		coordinator.lastRequestedFocus = isFocused
		coordinator.focusRequestID += 1
		let focusRequestID = coordinator.focusRequestID
		let requestedFocus = isFocused

		// Perform UIKit focus changes outside SwiftUI's update cycle
		DispatchQueue.main.async { [weak uiView, weak coordinator] in
			guard let uiView, let coordinator, coordinator.focusRequestID == focusRequestID, coordinator.parent.isFocused == requestedFocus else { return }

			if requestedFocus {
				if !uiView.isFirstResponder {
					uiView.becomeFirstResponder()
				}
			} else if uiView.isFirstResponder {
				uiView.resignFirstResponder()
			}
		}
	}

	final class Coordinator: NSObject, UITextViewDelegate {
		var parent: LogicTextEditor

		var keyboardHost: UIHostingController<LogicKeyboard>?
		var isUpdating = false
		var lastRequestedFocus = false
		var focusRequestID = 0

		init(_ parent: LogicTextEditor) {
			self.parent = parent
		}

		func textViewDidChange(_ textView: UITextView) {
			guard !isUpdating else { return }
			parent.text = textView.text
		}

		func textViewDidBeginEditing(_: UITextView) {
			lastRequestedFocus = true
			focusRequestID += 1

			guard !isUpdating else { return }

			if !parent.isFocused {
				parent.isFocused = true
			}
		}

		func textViewDidEndEditing(_: UITextView) {
			lastRequestedFocus = false
			focusRequestID += 1

			guard !isUpdating else { return }

			if parent.isFocused {
				parent.isFocused = false
			}
		}
	}
}
