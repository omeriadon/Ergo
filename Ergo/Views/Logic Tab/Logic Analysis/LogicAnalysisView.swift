//
//  LogicAnalysisView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

struct LogicAnalysisView: View {
	let analysis: LogicAnalysis
	let entries: [LogicKeyboardEntry]
	let onFix: (LogicFix) -> Void

	@Environment(CatalogStore.self)
	private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.logicLetters) var logicLetters

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			switch analysis.feedback {
				case let .unfinished(diagnostic):
					problem(diagnostic, symbol: "ellipsis.circle.fill", color: .secondary)

				case let .error(diagnostic):
					problem(diagnostic, symbol: "xmark.circle.fill", color: .red)

				case .contradictoryPremises:
					fallacy("inconsistency", detail: "Premises contradict each other, so any conclusion follows")

				case .circular:
					fallacy("circular-reasoning", detail: "Conclusion restates a premise")

				case .valid:
					MessageRow(
						symbol: "checkmark.seal.fill",
						color: .green,
						title: "Valid",
						detail: "Conclusion follows from the premises"
					)

				case let .invalid(counterexample, match):
					fallacy(
						match?.fallacyID ?? "non-sequitur",
						title: match == nil ? "Invalid" : nil,
						detail: failure(for: counterexample)
					) {
						CounterexampleView(
							premises: (match?.premises ?? Array(analysis.parse.argument.premises.indices)).map {
								text(analysis.parse.argument.premises[$0].range)
							},
							conclusion: analysis.parse.argument.conclusion.map { text($0.range) }
						)
					}

				case let .unchecked(match?):
					fallacy(match.fallacyID, detail: "Matches this pattern, but couldn't be proved either way")

				case .unchecked(nil):
					MessageRow(
						symbol: "questionmark.circle.fill",
						color: .secondary,
						title: "Couldn't be proved either way",
						detail: "This may be valid or invalid"
					)

				case let .statuses(statuses):
					ForEach(Array(statuses.prefix(3).enumerated()), id: \.offset) { index, status in
						statusRow(status, number: statuses.count == 1 ? nil : index + 1)
					}

					if statuses.count > 1 {
						MessageRow(
							symbol: "lightbulb",
							color: .secondary,
							title: "No conclusion",
							detail: "Add ∴ before the conclusion to check an argument"
						)
					}

				case nil:
					EmptyView()
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("logic.logicAnalysis")
	}

	private func problem(_ diagnostic: LogicDiagnostic, symbol: String, color: Color) -> some View {
		MessageRow(
			symbol: symbol,
			color: color,
			title: diagnostic.problem.message(letters: letters),
			detail: diagnostic.problem.advice(letters: letters)
		) {
			if let fix = diagnostic.fix {
				Button(label(for: fix)) {
					onFix(fix)
				}
				.buttonStyle(.glass)
				.controlSize(.small)
				.accessibilityIdentifier("logic.logicAnalysis.fix")
			}
		}
	}

	private func fallacy(_ id: String, title: String? = nil, detail: String? = nil) -> some View {
		fallacy(id, title: title, detail: detail) {
			EmptyView()
		}
	}

	/// Tapping opens the fallacy in the library, when the catalog has it
	private func fallacy(
		_ id: String,
		title: String? = nil,
		detail: String? = nil,
		@ViewBuilder extra: () -> some View
	) -> some View {
		let fallacy = catalog.fallacies.fallacies.first { $0.id == id }

		return MessageRow(
			symbol: "exclamationmark.triangle.fill",
			color: .orange,
			title: title ?? fallacy?.name ?? id.replacingOccurrences(of: "-", with: " ").capitalized,
			detail: detail,
			action: fallacy == nil ? nil : {
				navigation.openLibraryEntry(category: .fallacies, id: id)
			},
			extra: extra
		)
	}

	private func statusRow(_ status: LogicStatus, number: Int?) -> some View {
		let title = switch status {
			case .tautology: "Always true"
			case .contradiction: "Never true"
			case .contingent: "Could be true or false"
			case .undecided: "Couldn't be proved either way"
		}

		let symbol = switch status {
			case .tautology: "checkmark.circle.fill"
			case .contradiction: "xmark.circle.fill"
			case .contingent: "circle.lefthalf.filled"
			case .undecided: "questionmark.circle.fill"
		}

		let color: Color = switch status {
			case .tautology: .green
			case .contradiction: .red
			case .contingent, .undecided: .secondary
		}

		return MessageRow(
			symbol: symbol,
			color: color,
			title: number.map { "\($0). \(title)" } ?? title,
			detail: number == nil ? "Add ∴ before a conclusion to check an argument" : nil
		)
	}

	private func label(for fix: LogicFix) -> String {
		fix.replacement.isEmpty
			? "Remove '\(text(fix.range))'"
			: "Replace with '\(fix.replacement.map { $0.glyph(letters: letters) }.joined())'"
	}

	private func text(_ range: Range<Int>) -> String {
		let range = range.clamped(to: entries.indices)
		return entries[range].map { $0.glyph(letters: letters) }.joined()
	}

	/// "Conclusion fails when X is true and R is false"
	private func failure(for counterexample: [Int: Bool]) -> String {
		let parts = counterexample
			.sorted { $0.key < $1.key }
			.map { slot, value in
				LogicLetters.letter(for: slot, in: letters) + (value ? " is true" : " is false")
			}

		guard let last = parts.last else {
			return "Premises can be true while the conclusion is false"
		}

		let joined = parts.count == 1 ? last : parts.dropLast().joined(separator: ", ") + " and " + last
		return "Conclusion fails when \(joined)"
	}
}
