//
//  AnalysisStatusViews.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoProtocol
import ErgoSync
import SwiftUI

// MARK: - Status

struct AnalysisStatusView: View {
	let board: Board
	let hasStale: Bool

	@Environment(BoardAnalysisStore.self)
	private var analysis

	@Environment(BoardStore.self)
	private var boardStore

	private var isRunning: Bool {
		analysis.isRunning(board.id)
	}

	private var status: BoardAnalysisStatus? {
		analysis.statuses[board.id]
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 10) {
				if isRunning {
					ProgressView()
				}
				Text(headline)
					.font(.headline)
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier("analysis.status")

			if let detail {
				Text(detail)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			if let error = status?.error, analysis.status(of: board.id) == .failed {
				Text(error)
					.font(.subheadline)
					.foregroundStyle(.red)
			}

			if let message = analysis.messages[board.id] {
				Text(message.text)
					.font(.subheadline)
					.foregroundStyle(message.isError ? .red : .secondary)
					.accessibilityIdentifier("analysis.message")
			}

			// Only someone who can edit starts or stops a run
			if boardStore.canEdit(board.id) {
				button
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var headline: String {
		if analysis.starting.contains(board.id) {
			return "Starting"
		}
		return switch analysis.status(of: board.id) {
			case .running: "Analysing"
			case .finished: "Finished"
			case .failed: "Failed"
			case .cancelled: "Stopped"
			case .interrupted: "Interrupted"
			case nil: "Not analysed yet"
		}
	}

	private var detail: String? {
		if hasStale, !isRunning {
			return "The board has changed since this ran, so findings about what changed are hidden."
		}
		return switch analysis.status(of: board.id) {
			case .cancelled: "What it found before stopping is kept."
			case .interrupted: "The server restarted before it finished. What it found is kept."
			case .failed: "What it found before failing is kept."
			default: nil
		}
	}

	@ViewBuilder
	private var button: some View {
		if isRunning {
			if !analysis.starting.contains(board.id) {
				Button("Stop", systemImage: "stop.fill", role: .destructive) {
					analysis.stop(board: board.id)
				}
				.buttonStyle(.glass)
				.accessibilityIdentifier("analysis.stop")
			}
		} else {
			Button(status == nil ? "Analyse" : "Run Again", systemImage: "arrow.clockwise") {
				analysis.start(board: board)
			}
			.buttonStyle(.glass)
			.accessibilityIdentifier("analysis.run")
		}
	}
}

/// What the colours on the board mean
struct AnalysisKeyView: View {
	var body: some View {
		HStack(spacing: 14) {
			item("Holds up", .green)
			item("Partly", .orange)
			item("Doesn't follow", .red)
		}
		.font(.caption)
		.foregroundStyle(.secondary)
		.accessibilityIdentifier("analysis.key")
	}

	private func item(_ title: LocalizedStringKey, _ tint: Color) -> some View {
		HStack(spacing: 5) {
			Circle()
				.fill(tint)
				.frame(width: 8, height: 8)
			Text(title)
		}
	}
}

struct AnalysisDiscussionView: View {
	let board: Board.ID

	@Environment(BoardAnalysisStore.self)
	private var analysis

	var body: some View {
		if let discussion = analysis.statuses[board]?.discussion, !discussion.isEmpty {
			VStack(alignment: .leading, spacing: 8) {
				Text("Discussion")
					.font(.title3.bold())
				AskMarkdownView(text: discussion)
			}
			.accessibilityIdentifier("analysis.discussion")
		}
	}
}

struct AnalysisEmptyView: View {
	let board: Board.ID
	let hasStale: Bool

	@Environment(BoardAnalysisStore.self)
	private var analysis

	var body: some View {
		// Nothing yet is not the same as nothing found
		if !hasStale, !analysis.isRunning(board), analysis.status(of: board) != nil {
			Text("Nothing found")
				.font(.headline)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier("analysis.nothingFound")
		}
	}
}
