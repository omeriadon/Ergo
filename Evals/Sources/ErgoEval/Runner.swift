//
//  Runner.swift
//  Evals
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoClient
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

/// One translation of one case: everything the server sent, kept whole so a failure can be read afterwards
struct EvalRun: Codable, Sendable {
	let caseID: String

	/// Counts from 1, for `--repeat`
	let repetition: Int

	let messages: [TranslateServerMessage]
	let seconds: Double

	/// When the stream threw instead of ending with `.failed`: the server was unreachable or dropped the socket
	let thrown: ServiceError?

	var translation: Translation? {
		messages.lazy.compactMap { message in
			if case let .finished(translation) = message {
				translation
			} else {
				nil
			}
		}.first
	}

	/// The server's `.failed`, or what the client threw
	var error: ServiceError? {
		let failed = messages.lazy.compactMap { message in
			if case let .failed(error) = message {
				error
			} else {
				nil
			}
		}.first
		return failed ?? thrown
	}

	var events: [TranslationEvent] {
		messages.compactMap { message in
			if case let .event(event) = message {
				event
			} else {
				nil
			}
		}
	}

	/// Zero when it never got that far
	var formalizeAttempts: Int {
		events.reduce(0) { highest, event in
			if case let .started(.formalize, attempt) = event {
				max(highest, attempt)
			} else {
				highest
			}
		}
	}

	var verifyRan: Bool {
		events.contains { event in
			if case .started(.verify, _) = event {
				true
			} else {
				false
			}
		}
	}

	/// Gate let it through. Without this, a real argument coming back empty was taken for not being logic at all.
	var reachedBreakdown: Bool {
		events.contains { event in
			if case .started(.breakdown, _) = event {
				true
			} else {
				false
			}
		}
	}

	/// Verify still disagreed on the last attempt. Warnings on an empty translation are compile problems instead.
	var hasVerifyWarnings: Bool {
		guard let translation, !translation.entries.isEmpty else { return false }
		return translation.issues.contains { $0.severity == .warning }
	}
}

/// Sends cases through `ErgoClient`, the same path the app takes.
/// The server runs one translation per account at a time, so concurrency above 1 only helps across several accounts.
struct Runner: Sendable {
	let client: ErgoClient
	let provider: Provider
	let concurrency: Int

	/// Results in case order, whatever order they finish in. `progress` hears about each one as it finishes.
	func run(
		_ cases: [EvalCase],
		repetitions: Int,
		progress: @escaping @Sendable (EvalCase, EvalRun) -> Void
	) async -> [EvalRun] {
		let jobs = cases.flatMap { evalCase in (1 ... repetitions).map { (evalCase, $0) } }
		let width = max(1, min(concurrency, jobs.count))

		return await withTaskGroup(of: (Int, EvalRun).self) { group in
			var runs = [EvalRun?](repeating: nil, count: jobs.count)
			var next = 0

			for _ in 0 ..< width {
				let index = next
				group.addTask { await (index, translate(jobs[index].0, repetition: jobs[index].1)) }
				next += 1
			}

			for await (index, run) in group {
				runs[index] = run
				progress(jobs[index].0, run)

				guard next < jobs.count else { continue }
				let index = next
				group.addTask { await (index, translate(jobs[index].0, repetition: jobs[index].1)) }
				next += 1
			}

			return runs.compactMap(\.self)
		}
	}

	func translate(_ evalCase: EvalCase, repetition: Int) async -> EvalRun {
		let request = TranslateRequest(
			id: UUID(),
			english: evalCase.english,
			provider: provider,
			letters: Corpus.letters,
			grammarVersion: LogicGrammar.version,
			descriptors: evalCase.descriptors,
			scope: .statement
		)

		let clock = ContinuousClock()
		let start = clock.now
		var messages: [TranslateServerMessage] = []
		var thrown: ServiceError?

		do {
			for try await message in client.translate(request) {
				messages.append(message)
			}
		} catch let error as ServiceError {
			thrown = error
		} catch {
			thrown = ServiceError(code: .internalError, message: "\(error)")
		}

		let elapsed = (clock.now - start).components
		return EvalRun(
			caseID: evalCase.id,
			repetition: repetition,
			messages: messages,
			seconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
			thrown: thrown
		)
	}
}
