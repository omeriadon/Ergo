//
//  CheckTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import SwiftUI

struct CheckTabView: View {
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

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	/// Only shown while it still describes what's in the editor
	private var currentAnalysis: LogicAnalysis? {
		analyzedLogic == page.logic ? analysis : nil
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

	@State private var ditherSize = CGSize.zero

	var body: some View {
		@Bindable var pageStore = pageStore

		ZStack {
			VStack(spacing: 20) {
				VStack(alignment: .leading, spacing: 14) {
					TextEditor(text: $pageStore.current.english, selection: $englishSelection)
						.textEditorStyle(.plain)
						.focused($englishFocused)
						.accessibilityLabel("English editor")
						.accessibilityIdentifier("check.englishEditor")

					EnglishStatusView(
						issues: page.currentIssues,
						error: translationError?.message,
						setUp: setUp,
						isLogicOutdated: page.isLogicOutdated && !page.logic.isEmpty,
						progress: progress,
						canTranslate: !page.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
						translate: translate,
						stop: stopTranslating
					)
				}
				.animation(.smooth, value: page.currentIssues)
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
						entries: $pageStore.current.logic,
						isFocused: logicFocus,
						highlights: currentAnalysis?.highlights ?? [],
						descriptors: liveDescriptors ?? page.descriptors,
						onEditLetters: {
							navigation.presentSheet(.logicLetters)
						}
					)

					if let currentAnalysis {
						LogicAnalysisView(analysis: currentAnalysis, entries: page.logic) { fix in
							guard fix.range.upperBound <= page.logic.count else { return }
							pageStore.current.logic.replaceSubrange(fix.range, with: fix.replacement)
							pageStore.current.source = .logic
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
			.background(alignment: .top) {
				DitherView(configuration: detailViewConf)
					.frame(
						width: ditherSize.width,
						height: ditherSize.height
					)
					.ignoresSafeArea(.container)
					.allowsHitTesting(false)
			}
			.onGeometryChange(for: CGSize.self, of: { $0.size }) { _, size in
				guard size.width > 0, size.height > 0 else { return }

				if size.width == ditherSize.width {
					// Never shrink the background during keyboard presentation
					ditherSize.height = max(ditherSize.height, size.height)
				} else if focusedField == nil {
					ditherSize = size
				}
			}
		}
		.task(id: page.logic) {
			// Waits for a pause in typing, an instant verdict feels like it's grading every keystroke
			try? await Task.sleep(for: .seconds(1))
			guard !Task.isCancelled else { return }

			analyze()
		}
		.onChange(of: page.id) {
			// A page that's opened has already been written, no need to wait
			stopTranslating()
			englishSelection = nil
			translationError = nil
			analyze()
		}
		.onChange(of: pageStore.remoteEdits) {
			// Another device changed this page, and the selection was into the old English
			englishSelection = nil
		}
		.onChange(of: page.english) {
			translationError = nil
			if englishFocused {
				pageStore.current.source = .english
			}
		}
		.onChange(of: page.logic) {
			if focusedField == .logic {
				pageStore.current.source = .logic
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
				if focusedField == nil {
					Button("Pages", systemImage: "text.page.and.line.vertical.and.text.page") {
						navigation.presentSheet(.pages)
					}
					.accessibilityIdentifier("check.pagesButton")
				} else {
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
		let logic = page.logic
		analysis = logic.isEmpty ? nil : LogicChecker.analyze(logic)
		analyzedLogic = logic
		englishFollowsLogic()
	}

	/// When the logic was edited last, the English is read back from it.
	/// Waits for logic that parses, so half-written lines don't wipe the English.
	private func englishFollowsLogic() {
		guard page.source == .logic else { return }

		let english: String
		if page.logic.isEmpty {
			english = ""
		} else if let currentAnalysis, currentAnalysis.parse.diagnostics.isEmpty {
			english = LogicEnglish.text(for: currentAnalysis.parse.argument, letters: letters, descriptors: page.descriptors)
		} else {
			return
		}

		if page.english != english {
			pageStore.current.english = english
		}
	}

	// MARK: - Translating

	private func translate() {
		let english = page.english
		translationError = nil

		// Obviously bad input never reaches the server, and reads like any other translation issue
		if let problem = EnglishValidator.problem(with: english) {
			pageStore.current.translation = Translation(
				english: english,
				issues: [TranslationIssue(severity: .error, message: problem)]
			)
			return
		}

		let pageID = page.id
		let showsClaims = page.descriptors.allSatisfy(\.isEmpty)
		progress = TranslationProgress()

		translating = Task {
			do {
				let translation = try await account.translate(english: english, letters: letters) { event in
					guard !Task.isCancelled else { return }
					progress?.apply(event)
					if showsClaims, case let .foundClaims(_, _, descriptors) = event {
						liveDescriptors = descriptors
					}
				}
				guard !Task.isCancelled else { return }
				finishTranslating()
				apply(translation, english: english, to: pageID)
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

	private func apply(_ translation: Translation, english: String, to pageID: LogicPage.ID) {
		// The page or its English changed while the server worked
		guard page.id == pageID, page.english == english else { return }

		// Never trust the server's logic blindly
		guard LogicParser.parse(translation.entries).diagnostics.isEmpty else {
			translationError = ServiceError(code: .internalError, message: "Server sent logic that doesn't parse")
			return
		}

		// Keyed to the English as sent, so the page never thinks it's out of date
		pageStore.current.translation = Translation(
			english: english,
			entries: translation.entries,
			descriptors: translation.descriptors,
			issues: translation.issues
		)
		pageStore.current.source = .english
		// A failed translation only brings issues, the logic that was there stays
		if !translation.entries.isEmpty {
			pageStore.current.logic = translation.entries
			pageStore.current.descriptors = translation.descriptors
		}
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
