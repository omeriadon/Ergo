//
//  ScratchpadEditorView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

/// Logic over its reading in English, for the current scratchpad. It reads and writes through `ScratchpadStore`,
/// so it follows what other devices change. The English can only be copied.
struct ScratchpadEditorView: View {
	@Environment(\.dismiss)
	private var dismiss

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(ScratchpadStore.self)
	private var scratchpadStore

	@Default(.logicLetters) var logicLetters

	@State private var analysis: LogicAnalysis?
	@State private var analyzedLogic: [LogicKeyboardEntry] = []
	@State private var isLogicFocused = false
	@State private var cursor = LogicEditorCursor()

	private var scratchpad: LogicScratchpad {
		scratchpadStore.current
	}

	private var scratchpadBinding: Binding<LogicScratchpad> {
		Binding(
			get: { scratchpadStore.current },
			set: { scratchpadStore.current = $0 }
		)
	}

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	/// Only shown while it still describes what's in the editor
	private var currentAnalysis: LogicAnalysis? {
		analyzedLogic == scratchpad.logic ? analysis : nil
	}

	var body: some View {
		VStack(spacing: 20) {
			logicBox
			englishBox
		}
		.padding(15)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.safeAreaInset(edge: .bottom, spacing: 0) {
			if isLogicFocused {
				cursorKeys
					.transition(.opacity)
			}
		}
		.task(id: scratchpad.logic) {
			// Waits for a pause in typing, an instant verdict feels like it's grading every keystroke
			try? await Task.sleep(for: .seconds(1))
			guard !Task.isCancelled else { return }

			analyze()
		}
		.onAppear(perform: opened)
		.onChange(of: scratchpadStore.currentID, opened)
		.onChange(of: scratchpad.logic) {
			englishFollowsLogic()
		}
		.onChange(of: scratchpad.descriptors) {
			englishFollowsLogic()
		}
		.onChange(of: letters) {
			englishFollowsLogic()
		}
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				doneButton
			}
		}
		.animation(.easeInOut, value: isLogicFocused)
	}

	private var logicBox: some View {
		VStack(alignment: .leading, spacing: 14) {
			LogicTextEditor(
				entries: scratchpadBinding.logic,
				isFocused: $isLogicFocused,
				highlights: currentAnalysis?.highlights ?? [],
				cursor: cursor,
				descriptors: scratchpad.descriptors,
				onEditLetters: {
					navigation.presentSheet(.logicLetters)
				}
			)

			if let currentAnalysis {
				LogicAnalysisView(analysis: currentAnalysis, entries: scratchpad.logic) { fix in
					guard fix.range.upperBound <= scratchpad.logic.count else { return }
					scratchpadBinding.wrappedValue.logic.replaceSubrange(fix.range, with: fix.replacement)
				}
				.fixedSize(horizontal: false, vertical: true)
				.transition(.blurReplace)
			}
		}
		.animation(.smooth, value: currentAnalysis)
		.padding(15)
		.glassEffect(
			.regular.interactive(),
			in: RoundedRectangle(cornerRadius: 20)
		)
	}

	private var englishBox: some View {
		ScrollView {
			Text(scratchpad.english.isEmpty ? "The logic reads here as English" : scratchpad.english)
				.foregroundStyle(scratchpad.english.isEmpty ? .secondary : .primary)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(15)
				.padding(.trailing, 36)
				.accessibilityIdentifier("logic.english")
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.overlay(alignment: .topTrailing) {
			Button("Copy English", systemImage: "doc.on.doc") {
				UIPasteboard.general.string = scratchpad.english
			}
			.labelStyle(.iconOnly)
			.disabled(scratchpad.english.isEmpty)
			.padding(15)
			.accessibilityIdentifier("logic.copyEnglish")
		}
		.glassEffect(
			.regular,
			in: RoundedRectangle(cornerRadius: 20)
		)
	}

	/// In a safe area inset, so it sits on top of the keyboard. Holding one keeps moving.
	private var cursorKeys: some View {
		HStack(spacing: 10) {
			Button("Move left", systemImage: "arrow.left") {
				cursor.move(by: -1)
			}
			.accessibilityIdentifier("logic.cursorLeft")

			Button("Move right", systemImage: "arrow.right") {
				cursor.move(by: 1)
			}
			.accessibilityIdentifier("logic.cursorRight")

			Spacer(minLength: 0)
		}
		.labelStyle(.iconOnly)
		.buttonStyle(.glass)
		.buttonBorderShape(.circle)
		.controlSize(.large)
		.buttonRepeatBehavior(.enabled)
		.padding(.horizontal, 15)
		.padding(.bottom, 8)
	}

	private var doneButton: some View {
		// With the keyboard up the button puts it away, and then it closes the editor
		Button(role: .confirm) {
			if isLogicFocused {
				isLogicFocused = false
			} else {
				dismiss()
			}
		} label: {
			// Toolbar items don't pick up the animation on the body, so it has to be here
			ZStack {
				let symbol = isLogicFocused ? "checkmark" : "app.badge.checkmark"
				Image(systemName: symbol)
					.id(symbol)
					.transition(.blurReplace)
			}
			.animation(.smooth, value: isLogicFocused)
		}
		.buttonStyle(.glassProminent)
		.accessibilityLabel("Done")
		.accessibilityIdentifier("logic.doneButton")
	}

	/// A scratchpad that's opened has already been written, no need to wait. One with no logic keeps its English
	/// until there's logic to read, so opening an old one doesn't wipe it.
	private func opened() {
		analyze()
		if !scratchpad.logic.isEmpty {
			englishFollowsLogic()
		}
	}

	private func analyze() {
		let logic = scratchpad.logic
		analysis = logic.isEmpty ? nil : LogicChecker.analyze(logic)
		analyzedLogic = logic
	}

	/// On every keystroke, since parsing takes milliseconds. Logic that doesn't parse yet leaves the last reading,
	/// so half-written lines don't wipe it.
	private func englishFollowsLogic() {
		let english: String
		if scratchpad.logic.isEmpty {
			english = ""
		} else if let reading = LogicEnglish.text(for: LogicParser.parse(scratchpad.logic), letters: letters, descriptors: scratchpad.descriptors) {
			english = reading
		} else {
			return
		}

		if scratchpad.english != english {
			scratchpadBinding.wrappedValue.english = english
		}
	}
}
