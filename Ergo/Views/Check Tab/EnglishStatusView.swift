//
//  EnglishStatusView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoTranslation
import SwiftUI

/// Under the English box: how translating it is going, what went wrong, and the button to translate or stop
struct EnglishStatusView: View {
	let issues: [TranslationIssue]
	let error: String?

	/// Shown with the error when it's fixed in Settings, like a provider that isn't connected
	let setUp: (() -> Void)?

	let isLogicOutdated: Bool

	/// Nil when not translating
	let progress: TranslationProgress?

	let canTranslate: Bool
	let translate: () -> Void
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
							.accessibilityIdentifier("check.setUpTranslation")
					}
				}
			}

			ForEach(Array(issues.prefix(3).enumerated()), id: \.offset) { _, issue in
				switch issue.severity {
					case .error:
						MessageRow(symbol: "xmark.circle.fill", color: .red, title: issue.message)
					case .warning:
						MessageRow(symbol: "exclamationmark.triangle.fill", color: .orange, title: issue.message)
				}
			}

			if isLogicOutdated {
				MessageRow(
					symbol: "arrow.triangle.2.circlepath",
					color: .secondary,
					title: "Logic doesn't match the English",
					detail: "Translate to update it"
				)
			}

			HStack {
				Spacer(minLength: 0)

				if progress == nil {
					Button {
						translate()
					} label: {
						Label("Translate", systemImage: "arrow.down")
					}
					.buttonStyle(.glass)
					.disabled(!canTranslate)
					.accessibilityIdentifier("check.translateButton")
				} else {
					Button {
						stop()
					} label: {
						Label("Stop", systemImage: "stop.fill")
					}
					.buttonStyle(.glass)
					.accessibilityIdentifier("check.translateButton")
				}
			}
		}
		.animation(.smooth, value: progress)
		.fixedSize(horizontal: false, vertical: true)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("check.englishStatus")
	}
}

/// Laid out like `MessageRow`, with a spinner for the symbol
private struct ProgressRow: View {
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
		.accessibilityIdentifier("check.translationProgress")
	}
}
