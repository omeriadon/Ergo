//
//  BreakDownStatus.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoTranslation
import SwiftUI

// MARK: - Status

/// Under the text: how the breakdown is going, what went wrong, and the button to start or stop it
struct BreakDownStatusView: View {
	let error: String?

	/// Shown with the error when it's fixed in Settings, like a provider that isn't connected
	let setUp: (() -> Void)?

	let issues: [TranslationIssue]

	/// Nil when not breaking down
	let progress: TranslationProgress?

	/// How long the text is, when that's over the limit
	let overLimit: Int?
	let keepFirst: () -> Void

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

			if let overLimit {
				MessageRow(
					symbol: "exclamationmark.triangle.fill",
					color: .orange,
					title: "Expected at most \(EnglishValidator.characterLimit) characters, found \(overLimit). Cut it down to the part that matters."
				) {
					Button("Keep the Start", action: keepFirst)
						.buttonStyle(.glass)
						.accessibilityIdentifier("board.breakDown.keepStart")
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
struct IssueRows: View {
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
struct BreakdownResultView: View {
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

/// Laid out like `MessageRow`, with a spinner for the symbol
struct ProgressRow: View {
	let progress: TranslationProgress

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			ProgressView()
				.frame(width: 22)

			VStack(alignment: .leading, spacing: 2) {
				Text(progress.title)
					.font(.headline)
					.contentTransition(.opacity)

				if let detail = progress.detail {
					Text(detail)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.transition(.blurReplace)
				}
			}

			Spacer(minLength: 0)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier("logic.translationProgress")
	}
}
