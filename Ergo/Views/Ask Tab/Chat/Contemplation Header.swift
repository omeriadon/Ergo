//
//  Contemplation Header.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import SwiftUI

/// Reports `progress` of its content's own height, so a list can open and close with nothing measured
private struct AskReveal: Layout {
	var progress: CGFloat

	var animatableData: CGFloat {
		get { progress }
		set { progress = newValue }
	}

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
		let size = subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) ?? .zero
		return CGSize(width: size.width, height: size.height * progress)
	}

	func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
		subviews.first?.place(
			at: bounds.origin,
			anchor: .topLeading,
			proposal: ProposedViewSize(width: bounds.width, height: nil)
		)
	}
}

struct AskActivityHeader: View {
	let word: AskThinkingWord
	let tools: [String]
	let seconds: Int?

	/// Set while it's being written
	let run: AskStore.Run?

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@State private var isExpanded = false

	/// Having looked up nothing is worth saying too, since answers are meant to come from the library
	private var items: [String] {
		tools.isEmpty && run == nil ? ["Didn't check the library"] : tools
	}

	private static let itemDuration = 0.35
	private static let itemStagger = 0.1

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Button {
				isExpanded.toggle()
			} label: {
				header
			}
			.buttonStyle(.plain)
			.disabled(items.isEmpty)
			.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
			.accessibilityIdentifier("ask.activity")

			list
		}
	}

	/// Always there, so its own height is known. The container opens straight away and closes once the items have faded.
	private var list: some View {
		AskReveal(progress: isExpanded ? 1 : 0) {
			VStack(alignment: .leading, spacing: 6) {
				ForEach(Array(items.enumerated()), id: \.element) { index, item in
					Text(item)
						.font(.caption)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
						.opacity(isExpanded ? 1 : 0)
						.blur(radius: isExpanded || reduceMotion ? 0 : 6)
						.animation(itemAnimation(at: index), value: isExpanded)
						.accessibilityIdentifier("ask.tools")
				}
			}
			.padding(.top, 6)
		}
		.animation(listAnimation, value: isExpanded)
		.clipped()
		.accessibilityHidden(!isExpanded)
	}

	private var listAnimation: Animation? {
		guard !reduceMotion else { return .smooth(duration: 0.15) }
		guard !isExpanded else { return .smooth }
		return .smooth(duration: Self.itemDuration).delay(Double(max(items.count - 1, 0)) * Self.itemStagger)
	}

	private func itemAnimation(at index: Int) -> Animation {
		guard !reduceMotion else { return .smooth(duration: 0.15) }

		// Staggered down when opening, and back up when closing
		let step = isExpanded ? index : items.count - index - 1
		return .smooth(duration: Self.itemDuration).delay(Double(step) * Self.itemStagger)
	}

	private var header: some View {
		HStack(spacing: 5) {
			if run != nil {
				ProgressView()
					.controlSize(.mini)
			}

			TimelineView(.animation(minimumInterval: 1, paused: run == nil)) { context in
				let title = title(at: context.date)
				Text(title)
					.lineLimit(1)
					.contentTransition(.numericText())
					.animation(.smooth, value: title)
			}

			if !items.isEmpty {
				Image(systemName: "chevron.right")
					.font(.caption2.weight(.semibold))
					.rotationEffect(.degrees(isExpanded ? 90 : 0))
					.animation(.smooth, value: isExpanded)
					.transition(.opacity)
			}
		}
		.font(.caption)
		.foregroundStyle(.tertiary)
		.contentShape(Rectangle())
	}

	private func title(at date: Date) -> String {
		guard let run else {
			return seconds.map { "\(word.past) for \(Self.spelledOut($0))" } ?? word.past
		}
		return run.activity ?? "\(word.gerund) for \(Self.spelledOut(Int(date.timeIntervalSince(run.started))))"
	}

	private static func spelledOut(_ seconds: Int) -> String {
		Duration.seconds(max(seconds, 1)).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
	}
}
