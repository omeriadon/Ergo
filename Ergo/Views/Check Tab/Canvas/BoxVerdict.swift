//
//  BoxVerdict.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// What the checker made of a statement as the conclusion of its premises, boiled down to a badge on its box
nonisolated enum BoxVerdict: Equatable, Sendable {
	case valid

	/// `fallacy` is an id from the catalog, nil when the argument fails without matching a named form
	case invalid(fallacy: String?)

	/// Valid, but not for a good reason: the premises contradict each other, or one of them is the conclusion
	case flawed(String)

	/// The checker can't decide it yet
	case unknown

	case doesNotParse(String)

	init?(_ analysis: LogicAnalysis) {
		switch analysis.feedback {
			case .valid:
				self = .valid
			case .contradictoryPremises:
				self = .flawed("Inconsistent")
			case .circular:
				self = .flawed("Circular")
			case let .invalid(_, fallacy):
				self = .invalid(fallacy: fallacy?.fallacyID)
			case .unchecked:
				self = .unknown
			case .error, .unfinished:
				self = .doesNotParse("Expected a formula that parses, found one with mistakes")
			case .statuses, nil:
				return nil
		}
	}

	/// What the badge says, also read out by the box it sits on
	@MainActor
	func title(in catalog: CatalogStore) -> String {
		switch self {
			case .valid:
				"Valid"
			case let .invalid(fallacy):
				// A plain non sequitur is just "Invalid", the name says nothing the badge doesn't
				fallacy.flatMap { id in
					id == "non-sequitur" ? nil : catalog.fallacies.fallacies.first { $0.id == id }?.name
				} ?? "Invalid"
			case let .flawed(title):
				title
			case .unknown:
				"Can't tell"
			case .doesNotParse:
				"Doesn't parse"
		}
	}

	/// The verdict for every statement that has premises and logic to check. Runs off the main actor, since a
	/// truth table can have thousands of rows and there is one per conclusion.
	@concurrent
	static func all(in map: ArgumentMap<Statement, Link>) async -> [Statement.ID: BoxVerdict] {
		var verdicts: [Statement.ID: BoxVerdict] = [:]

		for statement in map.statements where map.isConclusion(statement.id) {
			guard !Task.isCancelled else { return verdicts }

			do {
				if let analysis = try ArgumentEntries.check(statement: statement.id, in: map), let verdict = BoxVerdict(analysis) {
					verdicts[statement.id] = verdict
				}
			} catch {
				verdicts[statement.id] = .doesNotParse(error.message)
			}
		}
		return verdicts
	}
}

// MARK: - Badge

/// The verdict on a box. Tapping it opens the full analysis.
struct VerdictBadge: View {
	let verdict: BoxVerdict
	let action: () -> Void

	@Environment(CatalogStore.self)
	private var catalog

	var body: some View {
		Button(action: action) {
			Label(title, systemImage: symbol)
				.font(.caption2.weight(.semibold))
				.lineLimit(1)
				.padding(.horizontal, 8)
				.padding(.vertical, 4)
				.background(color.opacity(0.2), in: Capsule())
				.foregroundStyle(color)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(title)
		.accessibilityHint("Shows the check")
		.accessibilityIdentifier("check.verdictBadge")
	}

	private var title: String {
		verdict.title(in: catalog)
	}

	private var symbol: String {
		switch verdict {
			case .valid: "checkmark.seal.fill"
			case .invalid, .flawed: "exclamationmark.triangle.fill"
			case .unknown: "questionmark.circle.fill"
			case .doesNotParse: "xmark.circle.fill"
		}
	}

	private var color: Color {
		switch verdict {
			case .valid: .green
			case .invalid, .flawed: .orange
			case .unknown: .secondary
			case .doesNotParse: .red
		}
	}
}
