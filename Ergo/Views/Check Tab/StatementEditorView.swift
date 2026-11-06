//
//  StatementEditorView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import SwiftUI

/// English over logic for one statement of the current board: the editor the Check tab has always been,
/// pointed at a statement. It reads and writes through `BoardStore`, so it follows what other devices change.
struct StatementEditorView: View {
	enum Field: Hashable {
		case english, logic
	}

	@Environment(\.dismiss)
	private var dismiss

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(TranslationAccount.self)
	private var account

	@Default(.logicLetters) var logicLetters

	/// A statement of `boardStore.current`
	let statementID: Statement.ID

	@State private var englishSelection: TextSelection?
	@FocusState private var englishFocused: Bool

	@State private var analysis: LogicAnalysis?
	@State private var analyzedLogic: [LogicKeyboardEntry] = []

	/// A failure isn't kept on the board, since it says nothing about the English
	@State private var run = TranslationRun<Never>.idle

	private var board: LogicBoard {
		boardStore.current
	}

	/// The claims found so far stand in on the keyboard, until the logic arrives, while the board names none
	private var keyboardDescriptors: [String] {
		if let claims = run.progress?.claims, board.descriptors.allSatisfy(\.isEmpty) {
			return claims
		}
		return board.descriptors
	}

	/// Empty once the statement is gone (deleted on another device), until the screen moves on
	private var statement: Statement {
		boardStore.statement(statementID) ?? Statement(id: statementID)
	}

	/// Writes are dropped once the statement is gone
	private var statementBinding: Binding<Statement> {
		boardStore.binding(for: statementID) ?? .constant(statement)
	}

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	/// Only shown while it still describes what's in the editor
	private var currentAnalysis: LogicAnalysis? {
		analyzedLogic == statement.logic ? analysis : nil
	}

	@State private var focusedField: Field?

	private var logicFocus: Binding<Bool> {
		Binding(
			get: {
				focusedField == .logic
			},
			set: { focused in
				if focused {
					focusedField = .logic
				} else if focusedField == .logic {
					focusedField = nil
				}
			}
		)
	}

	var body: some View {
		ZStack {
			VStack(spacing: 20) {
				VStack(alignment: .leading, spacing: 14) {
					TextEditor(text: statementBinding.english, selection: $englishSelection)
						.textEditorStyle(.plain)
						.focused($englishFocused)
						.accessibilityLabel("English editor")
						.accessibilityIdentifier("check.englishEditor")

					EnglishStatusView(
						issues: statement.currentIssues,
						error: run.failure?.message,
						setUp: setUp,
						isLogicOutdated: statement.isLogicOutdated && !statement.logic.isEmpty,
						progress: run.progress,
						canTranslate: !statement.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
						translate: translate,
						stop: stopTranslating
					)
				}
				.animation(.smooth, value: statement.currentIssues)
				.animation(.smooth, value: run.failure)
				.padding(15)
				.glassEffect(
					.regular.interactive(),
					in: RoundedRectangle(cornerRadius: 20)
				)
				.onChange(of: englishFocused) { _, focused in
					if focused {
						focusedField = .english
					} else if focusedField == .english {
						focusedField = nil
					}
				}

				VStack(alignment: .leading, spacing: 14) {
					LogicTextEditor(
						entries: statementBinding.logic,
						isFocused: logicFocus,
						highlights: currentAnalysis?.highlights ?? [],
						descriptors: keyboardDescriptors,
						onEditLetters: {
							navigation.presentSheet(.logicLetters)
						}
					)

					if let currentAnalysis {
						LogicAnalysisView(analysis: currentAnalysis, entries: statement.logic) { fix in
							guard fix.range.upperBound <= statement.logic.count else { return }
							statementBinding.wrappedValue.logic.replaceSubrange(fix.range, with: fix.replacement)
							statementBinding.wrappedValue.source = .logic
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
			.padding(15)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.task(id: statement.logic) {
			// Waits for a pause in typing, an instant verdict feels like it's grading every keystroke
			try? await Task.sleep(for: .seconds(1))
			guard !Task.isCancelled else { return }

			analyze()
		}
		.onChange(of: statementID) {
			// A statement that's opened has already been written, no need to wait
			stopTranslating()
			run = .idle
			englishSelection = nil
			analyze()
		}
		.onChange(of: boardStore.remoteEdits) {
			// Another device changed this board, and the selection was into the old English
			englishSelection = nil
		}
		.onChange(of: statement.english) {
			// Only a failure goes, a translation that's running carries on
			if run.failure != nil {
				run = .idle
			}
			if englishFocused {
				statementBinding.wrappedValue.source = .english
			}
		}
		.onChange(of: statement.logic) {
			if focusedField == .logic {
				statementBinding.wrappedValue.source = .logic
			}
		}
		.onChange(of: board.descriptors) {
			englishFollowsLogic()
		}
		.onChange(of: letters) {
			englishFollowsLogic()
		}
		.onDisappear {
			stopTranslating()
		}
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				// With the keyboard up the button puts it away, and then it closes the editor
				Button(role: .confirm) {
					if focusedField != nil {
						englishFocused = false
						focusedField = nil
					} else {
						dismiss()
					}
				} label: {
					// Toolbar items don't pick up the animation on the body, so it has to be here
					ZStack {
						let symbol = focusedField != nil ? "checkmark" : "app.badge.checkmark"
						Image(systemName: symbol)
							.id(symbol)
							.transition(.blurReplace)
					}
					.animation(.smooth, value: focusedField == nil)
				}
				.buttonStyle(.glassProminent)
				.accessibilityLabel("Done")
				.accessibilityIdentifier("check.doneButton")
			}
		}
		.animation(.easeInOut, value: focusedField == nil)
	}

	private func analyze() {
		let logic = statement.logic
		analysis = logic.isEmpty ? nil : LogicChecker.analyze(logic)
		analyzedLogic = logic
		englishFollowsLogic()
	}

	/// When the logic was edited last, the English is read back from it.
	/// Waits for logic that parses, so half-written lines don't wipe the English.
	private func englishFollowsLogic() {
		guard statement.source == .logic else { return }

		let english: String
		if statement.logic.isEmpty {
			english = ""
		} else if let currentAnalysis, currentAnalysis.parse.diagnostics.isEmpty {
			english = LogicEnglish.text(for: currentAnalysis.parse.argument, letters: letters, descriptors: board.descriptors)
		} else {
			return
		}

		if statement.english != english {
			statementBinding.wrappedValue.english = english
		}
	}

	// MARK: - Translating

	private func translate() {
		let english = statement.english
		run = .idle

		// Obviously bad input never reaches the server, and reads like any other translation issue
		if let problem = EnglishValidator.problem(with: english) {
			statementBinding.wrappedValue.translation = Translation(
				english: english,
				issues: [TranslationIssue(severity: .error, message: problem)]
			)
			return
		}

		let id = statementID
		let descriptors = board.descriptors

		let task = Task {
			do {
				let translation = try await account.translate(english: english, letters: letters, descriptors: descriptors) { event in
					guard !Task.isCancelled else { return }
					run.apply(event)
				}
				guard !Task.isCancelled else { return }
				run = .idle
				apply(translation, english: english, to: id)
			} catch {
				guard !Task.isCancelled, !(error is CancellationError) else { return }
				run = .failed(
					error as? ServiceError
						?? ServiceError(code: .internalError, message: error.localizedDescription)
				)
			}
		}
		run = .running(TranslationProgress(), task)
	}

	/// Closing the socket makes the server stop too
	private func stopTranslating() {
		run.cancel()
	}

	private func apply(_ translation: Translation, english: String, to id: Statement.ID) {
		// The statement or its English changed while the server worked
		guard statementID == id, statement.english == english else { return }

		// Never trust the server's logic blindly
		guard LogicParser.parse(translation.entries).diagnostics.isEmpty else {
			run = .failed(ServiceError(code: .internalError, message: "Server sent logic that doesn't parse"))
			return
		}

		boardStore.applyTranslation(translation, english: english, to: id)
	}

	/// Only for errors fixed by connecting a provider in Settings
	private var setUp: (() -> Void)? {
		switch run.failure?.code {
			case .notConnected, .credentialRejected:
				openSettings
			default:
				nil
		}
	}

	private func openSettings() {
		navigation.presentSheet(.settings(id: "3refd"))
	}
}
