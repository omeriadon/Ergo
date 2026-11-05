//
//  TranslationProgress.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoTranslation
import Foundation

/// The one live row the Check tab shows while the server translates, so a slow translation never looks stuck
struct TranslationProgress: Hashable {
	var title = "Connecting"
	var detail: String?

	mutating func apply(_ event: TranslationEvent) {
		switch event {
			case .started(.gate, _):
				title = "Reading the English"
				detail = nil

			case .started(.breakdown, _):
				title = "Finding premises and claims"
				detail = nil

			case let .foundClaims(premises, conclusion, descriptors):
				let claims = descriptors.count(where: { !$0.isEmpty })
				detail = [
					Self.count(premises.count, "premise"),
					Self.count(claims, "claim"),
					conclusion.isEmpty ? "no conclusion" : "conclusion found",
				].joined(separator: ", ")

			case let .started(.formalize, attempt):
				// Keeps the detail, which says what was found or why it's trying again
				title = attempt == 1 ? "Writing the logic" : "Writing the logic, try \(attempt)"

			case .started(.verify, _):
				title = "Checking it means the same"
				detail = nil

			case let .retrying(problems, _):
				detail = problems.first

			case .drafted:
				break
		}
	}

	private static func count(_ count: Int, _ noun: String) -> String {
		"\(count) \(noun)\(count == 1 ? "" : "s")"
	}
}
