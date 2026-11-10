//
//  PinAndArchive.swift
//  Ergo
//

import Defaults
import SwiftUI

/// For a chat or a board, in a menu or as a swipe
struct PinButton: View {
	let isPinned: Bool
	let toggle: () -> Void

	var body: some View {
		Button(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin", action: toggle)
			.tint(.yellow)
	}
}

/// For a chat or a board, in a menu or as a swipe
struct ArchiveButton: View {
	let isArchived: Bool
	let toggle: () -> Void

	var body: some View {
		Button(isArchived ? "Unarchive" : "Archive", systemImage: isArchived ? "tray.and.arrow.up" : "archivebox", action: toggle)
			.tint(.indigo)
	}
}

/// The way into what's been archived, at the top of a list
struct ArchivedRow: View {
	let count: Int
	let open: () -> Void

	var body: some View {
		Button(action: open) {
			HStack {
				Label("Archived", systemImage: "archivebox")
					.font(.headline)

				Spacer(minLength: 0)

				Text(count, format: .number)
					.foregroundStyle(.secondary)

				Image(systemName: "chevron.right")
					.foregroundStyle(.secondary)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityIdentifier("archived.row")
	}
}

extension View {
	/// Turns `isRevealed` on when a list is pulled down past its top, for a row that's out of sight until then. It goes
	/// again once the list has been left.
	func revealsArchived(_ isRevealed: Binding<Bool>, hasArchived: Bool) -> some View {
		modifier(ArchivedReveal(isRevealed: isRevealed, hasArchived: hasArchived))
	}
}

private struct ArchivedReveal: ViewModifier {
	/// How far past the top the list has to go
	private static let pull: CGFloat = 60

	@Binding var isRevealed: Bool
	let hasArchived: Bool

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	/// VoiceOver has no way to pull a list past its top, so the row's just there
	@Environment(\.accessibilityVoiceOverEnabled)
	private var voiceOver

	@Default(.hapticsEnabled) private var hapticsEnabled

	func body(content: Content) -> some View {
		content
			.onScrollGeometryChange(for: Bool.self) { geometry in
				geometry.contentOffset.y + geometry.contentInsets.top < -Self.pull
			} action: { _, isPulled in
				if isPulled, hasArchived {
					withAnimation(reduceMotion ? nil : .smooth) {
						isRevealed = true
					}
				}
			}
			.onChange(of: voiceOver, initial: true) {
				if voiceOver {
					isRevealed = true
				}
			}
			.onDisappear {
				if !voiceOver {
					isRevealed = false
				}
			}
			.sensoryFeedback(.impact(weight: .light), trigger: isRevealed) { _, new in new && hapticsEnabled }
	}
}
