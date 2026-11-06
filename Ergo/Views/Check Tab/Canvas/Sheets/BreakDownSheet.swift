//
//  BreakDownSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import SwiftUI

/// Pastes English and lets the server split it into premises and a conclusion, with no logic written. What it finds goes
/// on the page as statements joined by arrows (`PageStore.applyBreakdown`), and each one is translated on its own afterwards.
struct BreakDownSheet: View {
	@Environment(\.dismiss)
	private var dismiss

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(PageStore.self)
	private var pageStore

	@Environment(TranslationAccount.self)
	private var account

	@State private var english = ""
	@FocusState private var englishFocused: Bool

	@State private var translating: Task<Void, Never>?

	/// Nil when not breaking down
	@State private var progress: TranslationProgress?

	/// English that never reached the server, worded like a translation issue
	@State private var validation: String?

	/// The server couldn't break it down
	@State private var error: ServiceError?

	/// What the server found. Nil until it has, and again when you go back to edit the text.
	@State private var breakdown: ArgumentBreakdown?

	@State private var replacing = false
	@State private var confirmingReplace = false

	init() {}

	/// A breakdown with nothing in it only has issues to show, so the text stays editable
	private var found: ArgumentBreakdown? {
		guard let breakdown, !breakdown.premises.isEmpty || !breakdown.conclusion.isEmpty else { return nil }
		return breakdown
	}

	private var canBreakDown: Bool {
		!english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	/// Nothing on the page yet but the empty box every page starts with
	private var pageHasContent: Bool {
		pageStore.current.statements.contains { !$0.isEmpty }
	}

	var body: some View {
		NavigationStack {
			ZStack {
				if let found {
					BreakdownResultView(
						breakdown: found,
						application: found.applied(to: pageStore.current.map, replacing: replacing),
						replacing: $replacing
					)
				} else {
					input
				}
			}
			.animation(.smooth, value: found != nil)
			.toolbarTitleDisplayMode(.inline)
			.navigationTitle("Break Down")
			.toolbar { toolbar }
		}
		.presentationDetents([.large])
		.presentationDragIndicator(.visible)
		// A result is worth a model call, so swiping the sheet away doesn't throw it out. Cancel does.
		.interactiveDismissDisabled(translating != nil || found != nil)
		.onDisappear(perform: stop)
		.confirmationDialog(replaceTitle, isPresented: $confirmingReplace, titleVisibility: .visible) {
			Button("Replace Statements", role: .destructive, action: commit)
		} message: {
			Text("Every statement and arrow on this page is deleted first.")
		}
	}

	// MARK: - Parts

	private var input: some View {
		VStack(alignment: .leading, spacing: 14) {
			ZStack(alignment: .topLeading) {
				TextEditor(text: $english)
					.textEditorStyle(.plain)
					.focused($englishFocused)
					.scrollDismissesKeyboard(.interactively)
					.accessibilityLabel("Argument")
					.accessibilityIdentifier("check.breakDown.englishEditor")

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
				validation: validation,
				error: error?.message,
				setUp: setUp,
				issues: breakdown?.issues ?? [],
				progress: progress,
				canBreakDown: canBreakDown,
				breakDown: startBreakDown,
				stop: stop
			)
		}
		.padding(15)
		.animation(.smooth, value: error)
		.animation(.smooth, value: validation)
	}

	@ToolbarContentBuilder
	private var toolbar: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			Button(role: .cancel) {
				stop()
				dismiss()
			}
			.accessibilityIdentifier("check.breakDown.cancel")
		}

		if let found {
			ToolbarItem(placement: .topBarLeading) {
				Button("Edit Text", systemImage: "pencil") {
					breakdown = nil
				}
				.accessibilityIdentifier("check.breakDown.editText")
			}

			ToolbarItem(placement: .topBarTrailing) {
				Button(role: .confirm, action: apply) {
					Label(replacing ? "Replace" : "Add", systemImage: "checkmark")
				}
				.buttonStyle(.glassProminent)
				.disabled(found.applied(to: pageStore.current.map, replacing: replacing).added.isEmpty)
				.accessibilityLabel(replacing ? "Replace statements" : "Add to this page")
				.accessibilityIdentifier("check.breakDown.apply")
			}
		} else {
			ToolbarItem(placement: .keyboard) {
				Button("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") {
					englishFocused = false
				}
			}
		}
	}

	private var replaceTitle: String {
		let page = pageStore.current
		let statements = page.statements.count
		let links = page.links.count
		return "Replace \(statements) statement\(statements == 1 ? "" : "s")\(links == 0 ? "" : " and \(links) link\(links == 1 ? "" : "s")")?"
	}

	/// Only for errors fixed by connecting a provider in Settings
	private var setUp: (() -> Void)? {
		switch error?.code {
			case .notConnected, .credentialRejected:
				openSettings
			default:
				nil
		}
	}

	private func openSettings() {
		navigation.presentSheet(.settings(id: "3refd"))
	}

	// MARK: - Breaking down

	private func startBreakDown() {
		error = nil
		validation = nil
		breakdown = nil
		englishFocused = false

		let english = english
		// Obviously bad input never reaches the server, and reads like any other translation issue
		if let problem = EnglishValidator.problem(with: english) {
			validation = problem
			return
		}

		let descriptors = pageStore.current.descriptors
		progress = TranslationProgress()

		translating = Task {
			do {
				let result = try await account.breakDown(english: english, descriptors: descriptors) { event in
					guard !Task.isCancelled else { return }
					progress?.apply(event)
				}
				guard !Task.isCancelled else { return }
				finish()
				show(result)
			} catch {
				guard !Task.isCancelled, !(error is CancellationError) else { return }
				finish()
				self.error = error as? ServiceError
					?? ServiceError(code: .internalError, message: error.localizedDescription)
			}
		}
	}

	/// Closing the socket makes the server stop too
	private func stop() {
		translating?.cancel()
		finish()
	}

	private func finish() {
		translating = nil
		progress = nil
	}

	private func show(_ result: ArgumentBreakdown) {
		breakdown = result
		// Adding is the safe default, and a page with nothing on it has nothing to add to
		replacing = !pageHasContent
	}

	// MARK: - Applying

	private func apply() {
		if replacing, pageHasContent {
			confirmingReplace = true
		} else {
			commit()
		}
	}

	private func commit() {
		guard let found else { return }
		pageStore.applyBreakdown(found, replacing: replacing)
		dismiss()
	}
}

// MARK: - Status

/// Under the text: how the breakdown is going, what went wrong, and the button to start or stop it
private struct BreakDownStatusView: View {
	let validation: String?
	let error: String?

	/// Shown with the error when it's fixed in Settings, like a provider that isn't connected
	let setUp: (() -> Void)?

	let issues: [TranslationIssue]

	/// Nil when not breaking down
	let progress: TranslationProgress?

	let canBreakDown: Bool
	let breakDown: () -> Void
	let stop: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			if let progress {
				ProgressRow(progress: progress)
			}

			if let validation {
				MessageRow(symbol: "xmark.circle.fill", color: .red, title: validation)
			}

			if let error {
				MessageRow(symbol: "xmark.circle.fill", color: .red, title: error) {
					if let setUp {
						Button("Set Up", action: setUp)
							.buttonStyle(.glass)
							.accessibilityIdentifier("check.breakDown.setUp")
					}
				}
			}

			IssueRows(issues: issues)

			HStack {
				Spacer(minLength: 0)

				if progress == nil {
					Button {
						breakDown()
					} label: {
						Label("Break Down", systemImage: "arrow.triangle.branch")
					}
					.buttonStyle(.glassProminent)
					.disabled(!canBreakDown)
					.accessibilityIdentifier("check.breakDown.button")
				} else {
					Button {
						stop()
					} label: {
						Label("Stop", systemImage: "stop.fill")
					}
					.buttonStyle(.glass)
					.accessibilityIdentifier("check.breakDown.button")
				}
			}
		}
		.animation(.smooth, value: progress)
		.fixedSize(horizontal: false, vertical: true)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("check.breakDown.status")
	}
}

/// The server's issues, errors in red and warnings in orange
private struct IssueRows: View {
	let issues: [TranslationIssue]

	var body: some View {
		ForEach(Array(issues.prefix(3).enumerated()), id: \.offset) { _, issue in
			switch issue.severity {
				case .error:
					MessageRow(symbol: "xmark.circle.fill", color: .red, title: issue.message)
				case .warning:
					MessageRow(symbol: "exclamationmark.triangle.fill", color: .orange, title: issue.message)
			}
		}
	}
}

// MARK: - Result

/// What was found, and whether it goes on the page or replaces what's there
private struct BreakdownResultView: View {
	let breakdown: ArgumentBreakdown
	let application: ArgumentBreakdownApplication<Statement, Link>
	@Binding var replacing: Bool

	var body: some View {
		List {
			if !breakdown.issues.isEmpty {
				Section {
					IssueRows(issues: breakdown.issues)
				}
			}

			if !breakdown.premises.isEmpty {
				Section("Premises") {
					ForEach(Array(breakdown.premises.enumerated()), id: \.offset) { index, premise in
						Text(premise)
							.accessibilityLabel("Premise \(index + 1): \(premise)")
					}
				}
			}

			if !breakdown.conclusion.isEmpty {
				Section("Conclusion") {
					Text(breakdown.conclusion)
						.accessibilityLabel("Conclusion: \(breakdown.conclusion)")
				}
			}

			Section {
				Picker("Apply", selection: $replacing) {
					Text("Add to this page").tag(false)
					Text("Replace this page's statements").tag(true)
				}
				.pickerStyle(.inline)
				.labelsHidden()
				.accessibilityIdentifier("check.breakDown.mode")
			} footer: {
				fit
			}
		}
		.accessibilityIdentifier("check.breakDown.result")
	}

	/// Said before applying, so a page that's nearly full doesn't surprise anyone
	@ViewBuilder
	private var fit: some View {
		if application.skipped > 0 {
			let limit = ArgumentMapValidator.defaultMaximumStatements
			let found = application.map.statements.count + application.skipped
			Text("Expected at most \(limit) statements, found \(found). \(application.skipped) won't be added, starting from the last premise.")
				.foregroundStyle(.orange)
				.accessibilityIdentifier("check.breakDown.limit")
		}
	}
}
