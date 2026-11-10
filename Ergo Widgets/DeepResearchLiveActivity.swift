//
//  DeepResearchLiveActivity.swift
//  Ergo Widgets
//
//  Created by Adon Omeri on 10/11/2026.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct DeepResearchLiveActivity: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: DeepResearchAttributes.self) { context in
			DeepResearchLockScreen(attributes: context.attributes, phase: context.state.phase)
				.padding()
				.widgetURL(context.attributes.url)
		} dynamicIsland: { context in
			DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					DeepResearchSymbol(phase: context.state.phase)
				}
				DynamicIslandExpandedRegion(.trailing) {
					DeepResearchTime(attributes: context.attributes, phase: context.state.phase)
				}
				DynamicIslandExpandedRegion(.bottom) {
					Text(context.attributes.title)
						.lineLimit(1)
						.font(.subheadline)
				}
			} compactLeading: {
				DeepResearchSymbol(phase: context.state.phase)
			} compactTrailing: {
				DeepResearchTime(attributes: context.attributes, phase: context.state.phase)
			} minimal: {
				DeepResearchSymbol(phase: context.state.phase)
			}
			.widgetURL(context.attributes.url)
		}
	}
}

private struct DeepResearchLockScreen: View {
	let attributes: DeepResearchAttributes
	let phase: DeepResearchAttributes.Phase

	private var headline: String {
		switch phase {
			case .running: "Researching your board"
			case .finished: "Research finished"
			case .stopped: "Research stopped"
		}
	}

	var body: some View {
		HStack(spacing: 12) {
			DeepResearchSymbol(phase: phase)
				.font(.title2)

			VStack(alignment: .leading, spacing: 2) {
				Text(headline)
					.font(.headline)
				Text(attributes.title)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer(minLength: 0)

			DeepResearchTime(attributes: attributes, phase: phase)
		}
	}
}

private struct DeepResearchSymbol: View {
	let phase: DeepResearchAttributes.Phase

	var body: some View {
		switch phase {
			case .running:
				Image(systemName: "text.magnifyingglass")
			case .finished:
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(.green)
			case .stopped:
				Image(systemName: "stop.circle.fill")
					.foregroundStyle(.orange)
		}
	}
}

/// How long it's been going, while it is
private struct DeepResearchTime: View {
	let attributes: DeepResearchAttributes
	let phase: DeepResearchAttributes.Phase

	var body: some View {
		if phase == .running {
			Text(attributes.started, style: .timer)
				.monospacedDigit()
				.multilineTextAlignment(.trailing)
				.frame(maxWidth: 52)
		}
	}
}
