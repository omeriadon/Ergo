//
//  ArgumentCheckSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

/// The check behind a box's badge: the premises that point at it, the conclusion, and what `LogicAnalysisView` says
/// about them together.
struct ArgumentCheckSheet: View {
	let statementID: Statement.ID

	@Environment(\.dismiss)
	private var dismiss

	@Environment(BoardStore.self)
	private var boardStore

	@Default(.logicLetters) private var logicLetters

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	private var map: ArgumentMap<Statement, Link> {
		boardStore.current.map
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					argument
					verdict
				}
				.padding(20)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.toolbarTitleVire("Check", "")
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(role: .close) {
						dismiss()
					}
				}
			}
		}
		.presentationDetents([.medium, .large])
		.accessibilityIdentifier("check.argumentSheet")
	}

	// MARK: - Argument

	/// The premises in the order the checker reads them, then the conclusion
	private var argument: some View {
		VStack(alignment: .leading, spacing: 10) {
			ForEach(premiseIDs, id: \.self) { id in
				statementRow(id, marker: "•")
			}
			statementRow(statementID, marker: "∴")
		}
		.padding(15)
		.frame(maxWidth: .infinity, alignment: .leading)
		.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
	}

	private var premiseIDs: [Statement.ID] {
		let linked = Set(map.premises(of: statementID))
		return map.topologicalOrder().filter(linked.contains)
	}

	private func statementRow(_ id: Statement.ID, marker: String) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			Text(marker)
				.font(.headline)
				.foregroundStyle(.secondary)
				.frame(width: 18)

			if let statement = map.statement(id) {
				VStack(alignment: .leading, spacing: 2) {
					Text(statement.englishLine ?? StatementBoxView.title(of: statement, letters: letters))
						.font(.body)

					if statement.englishLine != nil, let logic = statement.logicLine(letters: letters) {
						Text(logic)
							.font(.callout.monospaced())
							.foregroundStyle(.secondary)
					}
				}
			}
		}
		.accessibilityElement(children: .combine)
	}

	// MARK: - Verdict

	/// Worked out when the sheet opens or the board changes: it's one argument, and it's only asked for when tapped
	@ViewBuilder
	private var verdict: some View {
		switch boardStore.check(statementID) {
			case let .success(analysis?):
				if analysis.parse.diagnostics.isEmpty, let argument = try? ArgumentEntries.build(for: statementID, in: map) {
					// A fix would edit the joined line, which isn't any one statement, so none is offered
					LogicAnalysisView(analysis: analysis, entries: argument.entries) { _ in }
				} else {
					MessageRow(symbol: "xmark.circle.fill", color: .red, title: "Expected an argument that parses, found one with mistakes")
				}

			case .success(nil):
				MessageRow(
					symbol: "ellipsis.circle.fill",
					color: .secondary,
					title: "Nothing to check yet",
					detail: "Every statement here needs some logic"
				)

			case let .failure(problem):
				MessageRow(
					symbol: "xmark.circle.fill",
					color: .red,
					title: problem.message,
					detail: map.statement(problem.statement).map { "In “\(StatementBoxView.title(of: $0, letters: letters))”" }
				)
		}
	}
}
