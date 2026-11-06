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

/// Pastes English and lets the server split it into premises and a conclusion, with no logic written. What it finds becomes
/// a new board of statements joined by arrows (`BoardStore.newBoard(from:)`). The claims it names are dropped, since a board holds English only.
struct BreakDownSheet: View {
	@Environment(\.dismiss)
	private var dismiss

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(TranslationAccount.self)
	private var account

	@State private var english = ""
	@FocusState private var englishFocused: Bool

	/// Finished holds what the server found, until you go back to edit the text
	@State private var run = TranslationRun<ArgumentBreakdown>.idle

	init() {}

	/// A breakdown with nothing in it only has issues to show, so the text stays editable
	private var found: ArgumentBreakdown? {
		guard let breakdown = run.output, !breakdown.premises.isEmpty || !breakdown.conclusion.isEmpty else { return nil }
		return breakdown
	}

	private var canBreakDown: Bool {
		!english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		NavigationStack {
			ZStack {
				if let found {
					BreakdownResultView(
						breakdown: found,
						application: found.applied(to: Board().map, replacing: true)
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
		.interactiveDismissDisabled(run.isRunning || found != nil)
		.onDisappear(perform: stop)
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
				canBreakDown: canBreakDown,
				breakDown: startBreakDown,
				stop: stop
			)
		}
		.padding(15)
		.animation(.smooth, value: run.failure)
	}

	@ToolbarContentBuilder
	private var toolbar: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			Button(role: .cancel) {
				stop()
				dismiss()
			}
			.accessibilityIdentifier("board.breakDown.cancel")
		}

		if found != nil {
			ToolbarItem(placement: .topBarLeading) {
				Button("Edit Text", systemImage: "pencil") {
					run = .idle
				}
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
					englishFocused = false
				}
			}
		}
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

	// MARK: - Breaking down

	private func startBreakDown() {
		run = .idle
		englishFocused = false

		let english = english
		// Obviously bad input never reaches the server, and reads like any other translation issue
		if let problem = EnglishValidator.problem(with: english) {
			run = .failed(ServiceError(code: .invalidRequest, message: problem))
			return
		}

		let task = Task {
			do {
				let result = try await account.breakDown(english: english, descriptors: LogicLetters.emptyDescriptors) { event in
					guard !Task.isCancelled else { return }
					run.apply(event)
				}
				guard !Task.isCancelled else { return }
				run = .finished(result)
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
	private func stop() {
		run.cancel()
	}

	// MARK: - Creating

	/// Closes the boards sheet too, since the new board is what's open now
	private func create() {
		guard let found else { return }
		boardStore.newBoard(from: found)
		navigation.dismissSheet()
	}
}

// MARK: - Status

/// Under the text: how the breakdown is going, what went wrong, and the button to start or stop it
private struct BreakDownStatusView: View {
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

			if let error {
				MessageRow(symbol: "xmark.circle.fill", color: .red, title: error) {
					if let setUp {
						Button("Set Up", action: setUp)
							.buttonStyle(.glass)
							.accessibilityIdentifier("board.breakDown.setUp")
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
					.accessibilityIdentifier("board.breakDown.button")
				} else {
					Button {
						stop()
					} label: {
						Label("Stop", systemImage: "stop.fill")
					}
					.buttonStyle(.glass)
					.accessibilityIdentifier("board.breakDown.button")
				}
			}
		}
		.animation(.smooth, value: progress)
		.fixedSize(horizontal: false, vertical: true)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("board.breakDown.status")
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

/// What was found, which is what the new board will hold
private struct BreakdownResultView: View {
	let breakdown: ArgumentBreakdown
	let application: ArgumentBreakdownApplication<Statement, Link>

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

			if application.skipped > 0 {
				Section {
					fit
				}
			}
		}
		.accessibilityIdentifier("board.breakDown.result")
	}

	/// Said before creating, so an argument too long for one board doesn't surprise anyone
	private var fit: some View {
		let limit = ArgumentMapValidator.defaultMaximumStatements
		let found = application.map.statements.count + application.skipped
		return Text("Expected at most \(limit) statements, found \(found). \(application.skipped) won't be added, starting from the last premise.")
			.foregroundStyle(.orange)
			.accessibilityIdentifier("board.breakDown.limit")
	}
}
