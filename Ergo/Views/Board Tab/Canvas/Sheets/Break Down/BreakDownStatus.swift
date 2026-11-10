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

	/// How many parts it would go in, when it's over the limit and that's possible
	let parts: Int?

	/// Which part is being worked on
	let partProgress: String?

	/// Set when going in parts is on a plan this account doesn't have
	let seePlus: (() -> Void)?
	let keepFirst: () -> Void

	let canBreakDown: Bool
	let breakDown: () -> Void
	let stop: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			if let progress {
				if let partProgress {
					Text(partProgress)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
						.contentTransition(.numericText())
						.accessibilityIdentifier("board.breakDown.part")
				}
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
					title: limitMessage(overLimit)
				) {
					HStack(spacing: 8) {
						if let seePlus {
							Button("See Ergo Plus", action: seePlus)
								.buttonStyle(.glass)
								.accessibilityIdentifier("board.breakDown.plus")
						}
						Button("Keep the Start", action: keepFirst)
							.buttonStyle(.glass)
							.accessibilityIdentifier("board.breakDown.keepStart")
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
						Label(buttonTitle, systemImage: "arrow.triangle.branch")
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

	private var buttonTitle: String {
		guard let parts, seePlus == nil else { return "Break Down" }
		return "Break Down in \(parts) Parts"
	}

	private func limitMessage(_ found: Int) -> String {
		let limit = "Expected at most \(EnglishValidator.characterLimit) characters, found \(found)."
		guard let parts else {
			return "\(limit) Cut it down to the part that matters."
		}
		if seePlus != nil {
			return "\(limit) Ergo Plus breaks longer texts down in parts."
		}
		return "Too long to break down at once, so it goes in \(parts) parts, each with its own region on the board."
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

/// What each part of a long text came to
struct BreakdownPartsView: View {
	let parts: [PendingBreakDown.Parts.Finished]

	var body: some View {
		List {
			ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
				Section("Part \(index + 1)") {
					ForEach(Array(part.breakdown.premises.enumerated()), id: \.offset) { _, premise in
						Text(premise)
					}
					if !part.breakdown.conclusion.isEmpty {
						Text(part.breakdown.conclusion)
							.fontWeight(.semibold)
							.accessibilityLabel("Conclusion: \(part.breakdown.conclusion)")
					}
				}
			}
		}
		.accessibilityIdentifier("board.breakDown.parts")
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
