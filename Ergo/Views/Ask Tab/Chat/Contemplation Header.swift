//
//  Contemplation Header.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import SwiftUI

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

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Button {
				withAnimation(.smooth) {
					isExpanded.toggle()
				}
			} label: {
				header
			}
			.buttonStyle(.plain)
			.disabled(items.isEmpty)
			.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
			.accessibilityIdentifier("ask.activity")

			if isExpanded {
				ForEach(Array(items.enumerated()), id: \.element) { index, item in
					Text(item)
						.font(.caption)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
						.transition(itemTransition(at: index))
						.accessibilityIdentifier("ask.tools")
				}
			}
		}
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

	/// Each one a beat after the last, falling out of the header
	private func itemTransition(at index: Int) -> AnyTransition {
		guard !reduceMotion else { return .opacity }
		return AnyTransition.opacity
			.combined(with: .offset(y: -6))
			.combined(with: AnyTransition(.blurReplace))
			.animation(.smooth.delay(Double(index) * 0.03))
	}
}
