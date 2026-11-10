//
//  DeepResearchActivity.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ActivityKit
import Foundation

/// Starts and ends the Live Activity. The server's run doesn't depend on any of this, and the server has no way to update
/// one: it ends when the app next hears the run is over, from a sync. `staleDate` covers a phone that never does.
@MainActor
enum DeepResearchActivity {
	private typealias Attributes = DeepResearchAttributes

	static func start(board: UUID, title: String, staleAfter: TimeInterval) {
		guard ActivityAuthorizationInfo().areActivitiesEnabled,
		      !Activity<Attributes>.activities.contains(where: { $0.attributes.board == board })
		else { return }

		let attributes = Attributes(board: board, title: title, started: .now)
		let content = ActivityContent(state: Attributes.ContentState(phase: .running), staleDate: .now.addingTimeInterval(staleAfter))
		_ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
	}

	/// `phase` says how a board's run ended, nil while it hasn't
	static func end(where phase: (UUID) -> DeepResearchAttributes.Phase?) {
		for activity in Activity<Attributes>.activities where activity.activityState == .active {
			guard let ended = phase(activity.attributes.board) else { continue }
			finish(activity.id, as: ended)
		}
	}

	static func endAll() {
		for activity in Activity<Attributes>.activities {
			finish(activity.id, as: .stopped)
		}
	}

	private static func finish(_ id: String, as phase: DeepResearchAttributes.Phase) {
		Task {
			await end(id, as: phase)
		}
	}

	/// Found again by id here, since an activity can't be handed from one actor to another
	private nonisolated static func end(_ id: String, as phase: DeepResearchAttributes.Phase) async {
		guard let activity = Activity<Attributes>.activities.first(where: { $0.id == id }) else { return }
		await activity.end(ActivityContent(state: Attributes.ContentState(phase: phase), staleDate: nil), dismissalPolicy: .default)
	}
}
