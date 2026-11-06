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

/// English over logic for one statement of the current page: the editor the Check tab has always been,
/// pointed at a statement. It reads and writes through `PageStore`, so it follows what other devices change.
struct StatementEditorView: View {
	enum Field: Hashable {
		case english, logic
	}

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(PageStore.self)
	private var pageStore

	@Environment(TranslationAccount.self)
	private var account

	@Default(.logicLetters) var logicLetters

	/// A statement of `pageStore.current`
	let statementID: Statement.ID

	@State private var englishSelection: TextSelection?
	@FocusState private var englishFocused: Bool

	@State private var analysis: LogicAnalysis?
	@State private var analyzedLogic: [LogicKeyboardEntry] = []

	@State private var translating: Task<Void, Never>?

	/// Nil when not translating
	@State private var progress: TranslationProgress?

	/// The claims found so far, shown on the keyboard before the logic arrives
	@State private var liveDescriptors: [String]?

	/// The server couldn't translate. Not kept on the page, since it says nothing about the English.
	@State private var translationError: ServiceError?

	private var page: LogicPage {
		pageStore.current
	}

	/// Empty once the statement is gone (deleted on another device), until the screen moves on
	private var statement: Statement {
		pageStore.statement(statementID) ?? Statement(id: statementID)
	}

	/// Writes are dropped once the statement is gone
	private var statementBinding: Binding<Statement> {
		pageStore.binding(for: statementID) ?? .constant(statement)
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
						error: translationError?.message,
						setUp: setUp,
						isLogicOutdated: statement.isLogicOutdated && !statement.logic.isEmpty,
						progress: progress,
						canTranslate: !statement.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
						translate: translate,
						stop: stopTranslating
					)
				}
				.animation(.smooth, value: statement.currentIssues)
				.animation(.smooth, value: translationError)
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
						descriptors: liveDescriptors ?? page.descriptors,
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
			englishSelection = nil
			translationError = nil
			analyze()
		}
		.onChange(of: pageStore.remoteEdits) {
			// Another device changed this page, and the selection was into the old English
			englishSelection = nil
		}
		.onChange(of: statement.english) {
			translationError = nil
			if englishFocused {
				statementBinding.wrappedValue.source = .english
			}
		}
		.onChange(of: statement.logic) {
			if focusedField == .logic {
				statementBinding.wrappedValue.source = .logic
			}
		}
		.onChange(of: page.descriptors) {
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
				if focusedField != nil {
					Button(role: .confirm) {
						englishFocused = false
						focusedField = nil
					} label: {
						Label("Done", systemImage: "checkmark")
					}
					.buttonStyle(.glassProminent)
					.accessibilityLabel("Done")
					.accessibilityIdentifier("check.doneButton")
				}
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
			english = LogicEnglish.text(for: currentAnalysis.parse.argument, letters: letters, descriptors: page.descriptors)
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
		translationError = nil

		// Obviously bad input never reaches the server, and reads like any other translation issue
		if let problem = EnglishValidator.problem(with: english) {
			statementBinding.wrappedValue.translation = Translation(
				english: english,
				issues: [TranslationIssue(severity: .error, message: problem)]
			)
			return
		}

		let id = statementID
		let descriptors = page.descriptors
		let showsClaims = descriptors.allSatisfy(\.isEmpty)
		progress = TranslationProgress()

		translating = Task {
			do {
				let translation = try await account.translate(english: english, letters: letters, descriptors: descriptors) { event in
					guard !Task.isCancelled else { return }
					progress?.apply(event)
					if showsClaims, case let .foundClaims(_, _, descriptors) = event {
						liveDescriptors = descriptors
					}
				}
				guard !Task.isCancelled else { return }
				finishTranslating()
				apply(translation, english: english, to: id)
			} catch {
				guard !Task.isCancelled, !(error is CancellationError) else { return }
				finishTranslating()
				translationError = error as? ServiceError
					?? ServiceError(code: .internalError, message: error.localizedDescription)
			}
		}
	}

	/// Closing the socket makes the server stop too
	private func stopTranslating() {
		translating?.cancel()
		finishTranslating()
	}

	private func finishTranslating() {
		translating = nil
		progress = nil
		liveDescriptors = nil
	}

	private func apply(_ translation: Translation, english: String, to id: Statement.ID) {
		// The statement or its English changed while the server worked
		guard statementID == id, statement.english == english else { return }

		// Never trust the server's logic blindly
		guard LogicParser.parse(translation.entries).diagnostics.isEmpty else {
			translationError = ServiceError(code: .internalError, message: "Server sent logic that doesn't parse")
			return
		}

		pageStore.applyTranslation(translation, english: english, to: id)
	}

	/// Only for errors fixed by connecting a provider in Settings
	private var setUp: (() -> Void)? {
		switch translationError?.code {
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
