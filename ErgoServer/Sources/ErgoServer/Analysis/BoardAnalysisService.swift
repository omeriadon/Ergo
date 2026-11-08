//
//  BoardAnalysisService.swift
//  ErgoServer
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoAsk
import ErgoCatalog
import ErgoProtocol
import Fluent
import Foundation
import Logging
import Synchronization

/// Analyses a board in the background with the user's own CLI login: the library's tools to read, and tools to report
/// what's relevant. Every report is checked by `BoardAnalysisTools`, then saved at once as an `annotation` record in
/// every member's row, so a run that dies keeps what it had. See `Plans/10-BoardAnalysis.md`.
///
/// A job outlives its request, so it only ever uses the database and logger it was given from the application.
struct BoardAnalysisService: Sendable {
	let translations: TranslationService
	let runs: AskRuns
	let sharing: BoardSharing
	let catalog: LibraryCatalog
	let jobs = BoardAnalysisJobs()

	/// A Codex login can only be used by one call at once, so a run waits this long for Ask's turn
	static let turnWait = Duration.seconds(300)
	static let turnPoll = Duration.seconds(3)

	/// What the discussion can hold, so a chatty model can't fill a record
	static let discussionCharacters = 40000

	private struct BoardGone: Error {}

	// MARK: - Starting

	/// Checks the request, records that it's running, and starts the job. Throws a `ServiceError`. `database` and `logger`
	/// are the request's own, for the checks. The job gets `jobDatabase` and `jobLogger`, which must not be.
	func start(
		_ request: BoardAnalysisRequest,
		board text: String?,
		account: UUID,
		port: Int,
		database: any Database,
		logger: Logger,
		jobDatabase: any Database,
		jobLogger: Logger
	) async throws {
		let boardID = try Self.boardID(text)
		let key = boardID.uuidString
		if let problem = request.problem {
			throw ServiceError(code: .invalidRequest, message: problem)
		}
		guard try await Credential.find(request.provider, for: account, on: database) != nil else {
			throw ServiceError(code: .notConnected, message: "\(request.provider.displayName) isn't connected")
		}
		let prompt = try StagePrompts.analysisMessage(for: request)

		try jobs.reserve(board: key, account: account, run: request.run)
		let started = Date.now
		let running = BoardAnalysisStatus(board: boardID, run: request.run, state: .running, started: started)
		do {
			try await sharing.change(board: boardID, caller: account, token: nil, on: database, logger: logger, now: started) { ledger, database in
				guard try await ledger.isLive(key, for: account, on: database) else {
					throw ServiceError(code: .invalidRequest, message: "Expected a synced board, sync and try again")
				}
				if let shared = try await ledger.shared(key, on: database), shared.member(of: account)?.boardRole.canEdit != true {
					throw ServiceError(code: .invalidRequest, message: "Expected a board you can edit, found one shared with you to view")
				}
				try await ledger.writeServerOwned(.analysis, id: key, fields: running.fields, board: key, requester: account, on: database)
			}
		} catch {
			jobs.release(board: key, run: request.run)
			throw error
		}

		let job = Job(service: self, request: request, board: boardID, account: account, started: started, prompt: prompt, port: port, database: jobDatabase, logger: jobLogger)
		let task = Task {
			await job.run()
		}
		jobs.attach(task, board: key, run: request.run)
		logger.info("Started a board analysis", metadata: [
			"provider": "\(request.provider)",
			"statements": "\(request.statements.count)",
			"links": "\(request.links.count)",
			"sources": "\(request.sources.count)",
		])
	}

	/// Stops the board's run, if the account started one, and keeps what's been written
	func stop(board text: String?, account: UUID) throws {
		try jobs.stop(board: Self.boardID(text).uuidString, by: account)
	}

	private static func boardID(_ text: String?) throws -> UUID {
		guard let text, let id = UUID(uuidString: text), id.uuidString == text else {
			throw ServiceError(code: .invalidRequest, message: "Expected a board id to be an uppercase UUID")
		}
		return id
	}

	// MARK: - The job

	/// What a run has heard so far
	private final class Heard: Sendable {
		private struct State {
			var discussion = ""
			var reports = 0
			var isGone = false
		}

		private let state = Mutex<State>(State())

		func add(text: String) {
			state.withLock { state in
				let room = BoardAnalysisService.discussionCharacters - state.discussion.count
				if room > 0 {
					state.discussion += text.prefix(room)
				}
			}
		}

		func saved() {
			state.withLock { $0.reports += 1 }
		}

		func markGone() {
			state.withLock { $0.isGone = true }
		}

		var reports: Int {
			state.withLock { $0.reports }
		}

		var isGone: Bool {
			state.withLock { $0.isGone }
		}

		var discussion: String? {
			let trimmed = state.withLock { $0.discussion }.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.isEmpty ? nil : trimmed
		}
	}

	private struct Job: Sendable {
		let service: BoardAnalysisService
		let request: BoardAnalysisRequest
		let board: UUID
		let account: UUID
		let started: Date
		let prompt: String
		let port: Int
		let database: any Database
		let logger: Logger

		var key: String {
			board.uuidString
		}

		func run() async {
			// Held until the final status is written, so a run started straight after can't be overwritten by this one's end
			defer { service.jobs.release(board: key, run: request.run) }
			let heard = Heard()
			let state: BoardAnalysisStatus.State
			var problem: String?
			do {
				try await analyse(heard)
				state = .finished
			} catch is CancellationError {
				state = .cancelled
			} catch let failure as ServiceError {
				state = .failed
				problem = failure.message
			} catch {
				state = .failed
				problem = ServiceError.internalFailure.message
			}

			// The board went away, or so is the database
			guard !heard.isGone, !service.jobs.isShuttingDown else { return }
			await finish(state, error: problem, discussion: heard.discussion)
			logger.info("Analysed a board", metadata: ["state": "\(state.rawValue)", "reports": "\(heard.reports)", "provider": "\(request.provider)"])
		}

		private func analyse(_ heard: Heard) async throws {
			let tools = AskToolServer(tools: BoardAnalysisTools(request: request, catalog: service.catalog))
			let token = service.runs.register { [self] body in
				await tools.respond(to: body) { event in
					guard case let .report(report) = event else { return }
					await save(report, heard: heard)
				}
			}
			defer { service.runs.remove(token) }

			let url = "http://127.0.0.1:\(port)/\(ErgoProtocol.Path.askTools)/\(token)"
			try await Self.waitingForTurn {
				// Claude Code has nothing to spend, so it needn't make Ask wait
				try await service.translations.withBackend(
					provider: request.provider,
					scope: "analysis",
					account: account,
					database: database,
					logger: logger,
					exclusive: request.provider == .codex
				) { backend in
					try await backend.ask(prompt: prompt, tools: url, settings: .analysis) { text in
						heard.add(text: text)
					}
				} summary: { _ in
					["reports": "\(heard.reports)"]
				}
			}
		}

		/// A Codex login keeps the one call at a time, so this waits for Ask's turn instead of failing
		private static func waitingForTurn(_ work: () async throws -> Void) async throws {
			let deadline = ContinuousClock.now + BoardAnalysisService.turnWait
			while true {
				do {
					return try await work()
				} catch let error as ServiceError where error.code == .busy && ContinuousClock.now < deadline {
					try await Task.sleep(for: BoardAnalysisService.turnPoll)
				}
			}
		}

		// MARK: - Writing

		/// Saved as soon as it's checked. A board that's gone stops the run without a word.
		private func save(_ report: BoardAnalysisReport, heard: Heard) async {
			let annotation = report.annotation(board: board, in: request)
			do {
				try await write { ledger, database in
					try await ledger.writeServerOwned(.annotation, id: annotation.recordID, fields: annotation.fields, board: key, requester: account, on: database)
				}
				heard.saved()
			} catch is BoardGone {
				heard.markGone()
				_ = try? service.jobs.stop(board: key, by: nil)
			} catch {
				logger.warning("Couldn't save an annotation", metadata: ["error": "\(String(reflecting: type(of: error)))"])
			}
		}

		/// How it went, for everyone on the board. A run that finished well also retires the last run's annotations.
		private func finish(_ state: BoardAnalysisStatus.State, error: String?, discussion: String?) async {
			let status = BoardAnalysisStatus(board: board, run: request.run, state: state, started: started, finished: .now, error: error, discussion: discussion)
			let key = key
			let run = request.run
			let account = account
			// Not inside this job, which may have been cancelled
			await Task {
				do {
					try await write { ledger, database in
						if state == .finished {
							try await ledger.tombstoneAnnotations(of: key, notFrom: run, requester: account, on: database)
						}
						try await ledger.writeServerOwned(.analysis, id: key, fields: status.fields, board: key, requester: account, on: database)
						let everyone = try await ledger.audience(of: key, requester: account, on: database)
						ledger.syncSilently(everyone, board: key)
					}
				} catch is BoardGone {
					return
				} catch {
					logger.error("Couldn't save how a board analysis went", metadata: ["error": "\(String(reflecting: type(of: error)))"])
				}
			}.value
		}

		/// One transaction with every member locked in order, as the sharing changes make them. Throws `BoardGone` when the
		/// board is deleted, or the person left or can no longer edit it.
		private func write(_ body: @escaping @Sendable (inout BoardLedger, any Database) async throws -> Void) async throws {
			let key = key
			let account = account
			try await service.sharing.change(board: board, caller: account, token: nil, on: database, logger: logger, now: .now) { ledger, database in
				guard try await ledger.isLive(key, for: account, on: database) else {
					throw BoardGone()
				}
				if let shared = try await ledger.shared(key, on: database), shared.member(of: account)?.boardRole.canEdit != true {
					throw BoardGone()
				}
				try await body(&ledger, database)
			}
		}
	}
}
