//
//  BoardAnalysisStore.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoProtocol
import ErgoShare
import ErgoSync
import Foundation
import SwiftUI

/// What the server's board analyses have written, read from the sync replica. Nothing here is saved: the replica already
/// is, and `refresh` reads it again on launch and after every sync, the way `BoardStore.shares` is.
///
/// What's shown is worked out each time from the board as it is (`shown(on:)`), never stored.
@MainActor
@Observable
final class BoardAnalysisStore {
	/// A line under the status: why starting failed, or which links were left out
	struct Message: Equatable {
		var text: String
		var isError: Bool
	}

	/// The newest status of each board's run
	private(set) var statuses: [Board.ID: BoardAnalysisStatus] = [:]

	/// Every live annotation, each with the stamp that says which run is newest
	private(set) var written: [Board.ID: [WrittenAnnotation]] = [:]

	/// Boards whose page text is being read or whose request is on its way, before the server says it's running
	private(set) var starting: Set<Board.ID> = []

	private(set) var messages: [Board.ID: Message] = [:]

	@ObservationIgnored weak var sync: SyncController?
	@ObservationIgnored weak var account: TranslationAccount?
	@ObservationIgnored private var tasks: [Board.ID: Task<Void, Never>] = [:]

	// MARK: - Reading

	func refresh(from replica: SyncReplica) {
		var statuses: [Board.ID: BoardAnalysisStatus] = [:]
		var written: [Board.ID: [WrittenAnnotation]] = [:]
		for record in replica.records.values where record.kind == .annotation || record.kind == .analysis {
			guard !replica.isIgnored(record) else { continue }
			if let status = BoardAnalysisStatus(record) {
				statuses[status.board] = status
			} else if let item = WrittenAnnotation(record) {
				written[item.annotation.board, default: []].append(item)
			}
		}
		if statuses != self.statuses {
			self.statuses = statuses
		}
		if written != self.written {
			self.written = written
		}
		endFinishedActivities()
	}

	/// A run started just now has no status yet, so it's left alone until it does
	private func endFinishedActivities() {
		DeepResearchActivity.end { board in
			guard !starting.contains(board), let status = status(of: board), status != .running else { return nil }
			return status == .finished ? .finished : .stopped
		}
	}

	/// Another account's results must not outlive its sign-in
	func reset() {
		for task in tasks.values {
			task.cancel()
		}
		tasks = [:]
		starting = []
		DeepResearchActivity.endAll()
		messages = [:]
		statuses = [:]
		written = [:]
	}

	func status(of board: Board.ID) -> BoardAnalysisStatus.Shown? {
		statuses[board]?.shown(at: .now)
	}

	/// Starting, or the server says it's going
	func isRunning(_ board: Board.ID) -> Bool {
		starting.contains(board) || status(of: board) == .running
	}

	/// Every board with a run going, newest first. One that's only starting has no status yet, so it counts as newest.
	func running(at now: Date) -> [Board.ID] {
		let started = statuses.values
			.filter { !starting.contains($0.board) && $0.shown(at: now) == .running }
			.sorted { $0.started > $1.started }
			.map(\.board)
		return starting.sorted { $0.uuidString < $1.uuidString } + started
	}

	func shown(on board: Board) -> BoardAnalysisShown {
		BoardAnalysisShown(written[board.id] ?? [], on: board.analysisSnapshot)
	}

	// MARK: - Running

	func start(board: Board) {
		guard tasks[board.id] == nil, let sync, let account else { return }
		messages[board.id] = nil
		starting.insert(board.id)
		tasks[board.id] = Task {
			defer {
				starting.remove(board.id)
				tasks[board.id] = nil
			}
			do {
				try await run(board, sync: sync, account: account)
			} catch is CancellationError {
			} catch {
				guard !Task.isCancelled else { return }
				messages[board.id] = Message(text: error.sharingMessage, isError: true)
			}
		}
	}

	private func run(_ board: Board, sync: SyncController, account: TranslationAccount) async throws {
		guard sync.isSignedIn else {
			throw TranslationAccount.notSignedIn
		}
		// The server reads the board from its own copy, so what's pending goes first
		try await sync.syncAndWait()

		let reading = await Self.request(for: board, provider: Defaults[.translationProvider])
		try Task.checkCancellation()
		if let problem = reading.request.problem {
			throw ServiceError(code: .invalidRequest, message: problem)
		}
		if !reading.skipped.isEmpty {
			messages[board.id] = Message(text: reading.skipped.joined(separator: "\n"), isError: false)
		}

		try await account.startAnalysis(board: BoardRecord.id(board.id), reading.request)
		DeepResearchActivity.start(board: board.id, title: board.title, staleAfter: BoardAnalysisStatus.staleAfter)
		// So there's something to say when it's done and the app is closed
		sync.askToNotify()
		await account.refreshUsage()
		// So the running status is here before the button goes back to idle
		try? await sync.syncAndWait()
	}

	func stop(board: Board.ID) {
		guard let sync, let account else { return }
		Task {
			do {
				try await account.stopAnalysis(board: BoardRecord.id(board))
				try? await sync.syncAndWait()
			} catch {
				messages[board] = Message(text: error.sharingMessage, isError: true)
			}
		}
	}

	// MARK: - Request

	private static func read(_ url: URL, of source: BoardSource) async -> (BoardSource, Result<String, any Error>) {
		do {
			return try await (source, .success(PageReader.read(url).text))
		} catch {
			return (source, .failure(error))
		}
	}

	/// What the server is sent. A link source's page is read here, since the CLI can't open links, and one that can't be
	/// read is left out and named in `skipped`.
	private static func request(for board: Board, provider: Provider) async -> (request: BoardAnalysisRequest, skipped: [String]) {
		var texts: [BoardSource.ID: String] = [:]
		var skipped: [String] = []

		await withTaskGroup(of: (BoardSource, Result<String, any Error>).self) { group in
			for source in board.sources {
				switch source.content {
					case let .text(text):
						texts[source.id] = text
					case let .link(url, _):
						group.addTask { await Self.read(url, of: source) }
				}
			}
			for await (source, result) in group {
				switch result {
					case let .success(text):
						texts[source.id] = text
					case let .failure(error):
						skipped.append("Expected to read \(source.title), left it out. \(error.sharingMessage)")
				}
			}
		}

		let linked = Set(board.links.flatMap { [$0.premise, $0.conclusion] })
		let request = BoardAnalysisRequest(
			run: UUID(),
			provider: provider,
			// An empty card that nothing joins has nothing to say
			statements: board.statements
				.filter { linked.contains($0.id) || !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
				.map { .init(id: $0.id, english: $0.english) },
			links: board.links.map { .init(id: $0.id, premise: $0.premise, conclusion: $0.conclusion) },
			sources: board.sources.compactMap { source in
				texts[source.id].map { .init(id: source.id, title: source.title, text: $0) }
			},
			instructions: Defaults[.agentInstructions]
		)
		return (request, skipped.sorted())
	}
}

// MARK: - The board as the analysis sees it

extension Board {
	var analysisSnapshot: BoardAnalysisSnapshot {
		BoardAnalysisSnapshot(
			statements: Dictionary(statements.map { ($0.id, $0.english) }, uniquingKeysWith: { first, _ in first }),
			links: links.map { .init(id: $0.id, premise: $0.premise, conclusion: $0.conclusion) },
			sources: sources.map { source in
				if case let .text(text) = source.content {
					.init(id: source.id, title: source.title, text: text)
				} else {
					.init(id: source.id, title: source.title, text: nil)
				}
			}
		)
	}
}

// MARK: - Wording

extension BoardAnalysisShown {
	/// How many current annotations each thing has. Ids are unique across cards, arrows and sources.
	var counts: [UUID: Int] {
		current.reduce(into: [:]) { counts, annotation in
			counts[annotation.target.id, default: 0] += 1
		}
	}

	/// What each arrow's assessment says, for how its line is drawn
	var strengths: [UUID: BoardArrowStrength] {
		var strengths: [UUID: BoardArrowStrength] = [:]
		for annotation in current {
			if case let .arrow(strength)? = annotation.assessment {
				strengths[annotation.target.id] = strength
			}
		}
		return strengths
	}

	/// What each conclusion's assessment says, for how its box is drawn
	var supports: [UUID: BoardConclusionSupport] {
		var supports: [UUID: BoardConclusionSupport] = [:]
		for annotation in current {
			if case let .conclusion(support)? = annotation.assessment {
				supports[annotation.target.id] = support
			}
		}
		return supports
	}
}

extension BoardArrowStrength {
	var label: String {
		switch self {
			case .conclusive: "Conclusive"
			case .strong: "Strong"
			case .weak: "Weak"
			case .none: "No support"
		}
	}

	var tint: Color {
		switch self {
			case .conclusive, .strong: .green
			case .weak: .orange
			case .none: .red
		}
	}
}

extension BoardConclusionSupport {
	var label: String {
		switch self {
			case .wellSupported: "Well supported"
			case .partlySupported: "Partly supported"
			case .unsupported: "Unsupported"
		}
	}

	var tint: Color {
		switch self {
			case .wellSupported: .green
			case .partlySupported: .orange
			case .unsupported: .red
		}
	}

	/// So what the colour says doesn't depend on seeing colour
	var symbol: String {
		switch self {
			case .wellSupported: "checkmark.circle.fill"
			case .partlySupported: "exclamationmark.triangle.fill"
			case .unsupported: "xmark.octagon.fill"
		}
	}
}
