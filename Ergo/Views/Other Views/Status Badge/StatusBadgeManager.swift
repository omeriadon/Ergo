//
//  StatusBadgeManager.swift
//  Ergo
//
//  Brought over from Timetable.
//

import Defaults
import ErgoProtocol
import Foundation
import Observation
import SwiftUI

enum StatusBadgeView: Equatable {
	case progressView
	case success
	case error
	case warning
	case info
	case progressViewAndGauge(currentStep: Int, totalSteps: Int)

	fileprivate var rank: Int {
		switch self {
			case .error: 4
			case .success: 3
			case .warning, .info: 2
			case .progressView, .progressViewAndGauge: 1
		}
	}

	var showsProgressBackground: Bool {
		switch self {
			case .progressView, .progressViewAndGauge:
				true
			default:
				false
		}
	}
}

enum StatusBadgeWidth: Equatable {
	case standard
	case flexible
}

struct StatusBadge: Identifiable, Equatable {
	let id: UUID
	var title: String
	var secondaryText: String?
	var priority: Int
	var view: StatusBadgeView
	var width: StatusBadgeWidth
	var dismissalDuration: Duration?
	let sequence: UInt64
}

/// The badges that drop down from the top of the screen, over whatever's showing. Anything can add one, and they queue:
/// one shows at a time, errors first.
@MainActor
@Observable
final class StatusBadgeManager {
	static let shared = StatusBadgeManager()

	/// Where the badge is on screen, so `StatusBadgeWindow` only takes the touches that land on it
	@ObservationIgnored var badgeFrame: CGRect = .zero

	private(set) var badges: [StatusBadge] = []
	private(set) var activeBadgeID: UUID?

	@ObservationIgnored private var nextSequence: UInt64 = 0
	@ObservationIgnored private var removalTasks: [UUID: Task<Void, Never>] = [:]
	@ObservationIgnored private var removalGenerations: [UUID: UInt64] = [:]

	var mainBadge: StatusBadge? {
		if let activeBadgeID,
		   let active = badges.first(where: { $0.id == activeBadgeID })
		{
			return active
		}
		return nil
	}

	func addBadge(
		id: UUID,
		title: String,
		secondaryText: String? = nil,
		priority: Int,
		view: StatusBadgeView,
		width: StatusBadgeWidth = .standard,
		dismissalDuration: Duration? = nil
	) {
		playHaptic(for: view)
		if let index = badges.firstIndex(where: { $0.id == id }) {
			guard badges[index].view != .success else { return }
			invalidateRemoval(for: id)
			badges[index].title = title
			badges[index].secondaryText = secondaryText
			badges[index].priority = min(max(priority, 1), 5)
			badges[index].view = view
			badges[index].width = width
			badges[index].dismissalDuration = dismissalDuration
		} else {
			nextSequence += 1
			badges.append(
				StatusBadge(
					id: id,
					title: title,
					secondaryText: secondaryText,
					priority: min(max(priority, 1), 5),
					view: view,
					width: width,
					dismissalDuration: dismissalDuration,
					sequence: nextSequence
				)
			)
		}

		activateNextBadgeIfNeeded()
		scheduleRemovalIfNeeded(for: id, view: view, durationOverride: dismissalDuration)
	}

	func updateBadge(
		id: UUID,
		title: String,
		secondaryText: String? = nil,
		view: StatusBadgeView
	) {
		guard let index = badges.firstIndex(where: { $0.id == id }),
		      badges[index].view != .success
		else { return }

		invalidateRemoval(for: id)
		badges[index].title = title
		badges[index].secondaryText = secondaryText
		badges[index].view = view
		playHaptic(for: view)

		scheduleRemovalIfNeeded(
			for: id,
			view: view,
			durationOverride: badges[index].dismissalDuration
		)
	}

	func dismissMainBadge() {
		guard let mainBadge else { return }
		removeBadge(id: mainBadge.id)
	}

	/// A failure worth interrupting for. A `ServiceError`'s message is already worded to show as is.
	func present(error: any Error, title: String) {
		guard !(error is CancellationError) else { return }
		let detail = (error as? ServiceError)?.message ?? error.localizedDescription
		addBadge(id: UUID(), title: title, secondaryText: detail, priority: 4, view: .error, width: .flexible)
	}

	private func playHaptic(for view: StatusBadgeView) {
		guard Defaults[.hapticsEnabled] else { return }
		switch view {
			case .success:
				UINotificationFeedbackGenerator().notificationOccurred(.success)
			case .error:
				UINotificationFeedbackGenerator().notificationOccurred(.error)
			case .warning:
				UINotificationFeedbackGenerator().notificationOccurred(.warning)
			case .info, .progressView, .progressViewAndGauge:
				break
		}
	}

	private var rankedBadges: [StatusBadge] {
		badges.sorted {
			if $0.view.rank != $1.view.rank {
				return $0.view.rank > $1.view.rank
			}
			if $0.priority != $1.priority {
				return $0.priority > $1.priority
			}
			return $0.sequence < $1.sequence
		}
	}

	private func activateNextBadgeIfNeeded() {
		guard activeBadgeID == nil else { return }
		activeBadgeID = rankedBadges.first?.id
		guard let mainBadge else { return }
		scheduleRemovalIfNeeded(
			for: mainBadge.id,
			view: mainBadge.view,
			durationOverride: mainBadge.dismissalDuration
		)
	}

	private func scheduleRemovalIfNeeded(
		for id: UUID,
		view: StatusBadgeView,
		durationOverride: Duration?
	) {
		guard activeBadgeID == id else { return }
		if let durationOverride {
			scheduleRemoval(for: id, after: durationOverride)
			return
		}
		let duration: Duration
		switch view {
			case .success:
				duration = .seconds(2)
			case .error, .warning, .info:
				duration = .seconds(5)
			default:
				return
		}

		scheduleRemoval(for: id, after: duration)
	}

	private func scheduleRemoval(for id: UUID, after duration: Duration) {
		invalidateRemoval(for: id)
		let generation = removalGenerations[id, default: 0]
		removalTasks[id] = Task { [weak self] in
			do {
				try await Task.sleep(for: duration)
			} catch {
				return
			}
			guard !Task.isCancelled, let self, removalGenerations[id] == generation else { return }
			removeBadge(id: id, generation: generation)
		}
	}

	private func invalidateRemoval(for id: UUID) {
		removalGenerations[id, default: 0] &+= 1
		removalTasks[id]?.cancel()
		removalTasks[id] = nil
	}

	private func removeBadge(id: UUID, generation: UInt64? = nil) {
		if let generation, removalGenerations[id] != generation {
			return
		}
		invalidateRemoval(for: id)
		badges.removeAll(where: { $0.id == id })
		if activeBadgeID == id {
			activeBadgeID = nil
			activateNextBadgeIfNeeded()
		}
	}
}

extension EnvironmentValues {
	@Entry var statusBadgeManager: StatusBadgeManager = .shared
}
