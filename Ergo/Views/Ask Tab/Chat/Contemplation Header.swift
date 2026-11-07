//
//  Contemplation Header.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import SwiftUI

private struct AskActivityHeightKey: PreferenceKey {
	static var defaultValue: CGFloat = 0

	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		value = nextValue()
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

	@State private var containerHeight: CGFloat = 0
	@State private var expandedContentHeight: CGFloat = 0

	private static let itemDuration = 0.35
	private static let itemStagger = 0.1

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Button {
				toggleExpanded()
			} label: {
				header
			}
			.buttonStyle(.plain)
			.disabled(items.isEmpty)
			.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
			.accessibilityIdentifier("ask.activity")

			// Independent measurement. Does not contribute to layout.
			Color.clear
				.frame(height: 0)
				.frame(maxWidth: .infinity)
				.overlay(alignment: .topLeading) {
					measuredItems
						.background {
							GeometryReader { proxy in
								Color.clear.preference(
									key: AskActivityHeightKey.self,
									value: proxy.size.height
								)
							}
						}
						.hidden()
						.accessibilityHidden(true)
				}

			// Actual displayed content.
			VStack(alignment: .leading, spacing: 6) {
				if isExpanded {
					ForEach(Array(items.enumerated()), id: \.element) { index, item in
						Text(item)
							.font(.caption)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
							.transition(itemTransition(at: index, total: items.count))
							.accessibilityIdentifier("ask.tools")
					}
				}
			}
			.padding(.top, 6)
			.frame(height: containerHeight, alignment: .top)
			.clipped()
		}
		.onPreferenceChange(AskActivityHeightKey.self) { height in
			guard height > 0 else { return }

			expandedContentHeight = height

			if isExpanded {
				var transaction = Transaction()
				transaction.animation = nil

				withTransaction(transaction) {
					containerHeight = height
				}
			}
		}
	}

	private var measuredItems: some View {
		VStack(alignment: .leading, spacing: 6) {
			ForEach(items, id: \.self) { item in
				Text(item)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(.top, 6)
		.fixedSize(horizontal: false, vertical: true)
	}

	private func toggleExpanded() {
		if isExpanded {
			let totalDuration = Double(max(items.count - 1, 0)) * Self.itemStagger + Self.itemDuration

			// Trigger item removal animations
			withAnimation(.smooth) {
				isExpanded = false
			}

			let halfDuration = totalDuration / 2

			guard !reduceMotion else {
				containerHeight = 0
				return
			}

			// Collapse container height after items begin fading out
			withAnimation(
				.smooth(duration: halfDuration)
					.delay(halfDuration)
			) {
				containerHeight = 0
			}
		} else {
			// Expand container height and trigger staggered item insertion transitions
			withAnimation(.smooth) {
				containerHeight = expandedContentHeight
				isExpanded = true
			}
		}
	}

	private func itemTransition(at index: Int, total: Int) -> AnyTransition {
		guard !reduceMotion else {
			return .opacity.animation(.smooth(duration: 0.15))
		}

		let insertionDelay = Double(index) * Self.itemStagger
		let removalDelay = Double(total - index - 1) * Self.itemStagger

		return .asymmetric(
			insertion: AnyTransition(.blurReplace)
				.animation(
					.smooth(duration: Self.itemDuration)
						.delay(insertionDelay)
				),
			removal: AnyTransition(.blurReplace)
				.animation(
					.smooth(duration: Self.itemDuration)
						.delay(removalDelay)
				)
		)
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

	/// What its tools are doing right now says more than how long it's been
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
