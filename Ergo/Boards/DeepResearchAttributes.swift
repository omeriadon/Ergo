//
//  DeepResearchAttributes.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ActivityKit
import Foundation

/// The Live Activity while a board's deep research runs. Compiled into the widget too, so it only uses plain types.
nonisolated struct DeepResearchAttributes: ActivityAttributes {
	enum Phase: String, Codable, Hashable {
		case running, finished, stopped
	}

	struct ContentState: Codable, Hashable {
		var phase: Phase
	}

	var board: UUID
	var title: String
	var started: Date

	/// What a tap on the activity opens: `ergo://research/<board>`
	var url: URL? {
		URL(string: "ergo://research/\(board.uuidString)")
	}

	static func board(from url: URL) -> UUID? {
		guard url.scheme == "ergo", url.host == "research" else { return nil }
		let parts = url.pathComponents.filter { $0 != "/" }
		guard parts.count == 1 else { return nil }
		return UUID(uuidString: parts[0])
	}
}
