//
//  BreakDownParts.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoTranslation
import SwiftUI

// MARK: - Parts

/// The text to break down, and the status under it
struct BreakDownInputForm: View {
	@Binding var english: String
	var focused: FocusState<Bool>.Binding
	let run: TranslationRun<ArgumentBreakdown>
	let setUp: (() -> Void)?
	let overLimit: Int?
	let parts: Int?
	let partProgress: String?
	let seePlus: (() -> Void)?
	let canBreakDown: Bool
	let breakDown: () -> Void
	let stop: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			ZStack(alignment: .topLeading) {
				TextEditor(text: $english)
					.textEditorStyle(.plain)
					.focused(focused)
					.scrollDismissesKeyboard(.interactively)
					.accessibilityLabel("Argument")
					.accessibilityIdentifier("board.breakDown.englishEditor")

				if english.isEmpty {
					Text("Paste an argument and the premises and conclusion are found for you.")
						.foregroundStyle(.tertiary)
						.padding(.horizontal, 5)
						.padding(.vertical, 8)
						.allowsHitTesting(false)
						.accessibilityHidden(true)
				}
			}
			.padding(15)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))

			BreakDownStatusView(
				error: run.failure?.message,
				setUp: setUp,
				issues: run.output?.issues ?? [],
				progress: run.progress,
				overLimit: overLimit,
				parts: parts,
				partProgress: partProgress,
				seePlus: seePlus,
				keepFirst: { english = SharedText.cut(english, to: EnglishValidator.characterLimit) },
				canBreakDown: canBreakDown,
				breakDown: breakDown,
				stop: stop
			)
		}
		.padding(15)
		.animation(.smooth, value: run.failure)
	}
}

/// Cancel, and either Edit Text and Create or the keyboard's Hide button
struct BreakDownToolbar: ToolbarContent {
	let hasResult: Bool
	var focused: FocusState<Bool>.Binding
	let cancel: () -> Void
	let editText: () -> Void
	let create: () -> Void

	var body: some ToolbarContent {
		ToolbarItem(placement: .sheetDismissal) {
			Button(role: .cancel, action: cancel)
				.accessibilityIdentifier("board.breakDown.cancel")
		}

		if hasResult {
			ToolbarItem(placement: .topBarLeading) {
				Button("Edit Text", systemImage: "pencil", action: editText)
					.accessibilityIdentifier("board.breakDown.editText")
			}

			ToolbarItem(placement: .topBarTrailing) {
				Button(role: .confirm, action: create) {
					Label("Create", systemImage: "checkmark")
				}
				.buttonStyle(.glassProminent)
				.accessibilityLabel("Create board")
				.accessibilityIdentifier("board.breakDown.apply")
			}
		} else {
			ToolbarItem(placement: .keyboard) {
				Button("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") {
					focused.wrappedValue = false
				}
			}
		}
	}
}
