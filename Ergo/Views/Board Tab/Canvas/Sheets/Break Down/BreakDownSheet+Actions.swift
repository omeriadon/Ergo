//
//  BreakDownSheet+Actions.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoTranslation
import SwiftUI

extension BreakDownSheet {
	// MARK: - Breaking down

	func startBreakDown() {
		run = .idle
		englishFocused = false

		finishedParts = []
		partProgress = nil

		let english = english
		if overLimit != nil {
			startParts(of: english)
			return
		}
		// Obviously bad input never reaches the server, and reads like any other translation issue
		if let problem = EnglishValidator.problem(with: english) {
			run = .failed(ServiceError(code: .invalidRequest, message: problem))
			return
		}

		let request = account.breakDownRequest(english: english, descriptors: LogicLetters.emptyDescriptors)
		let pending = PendingBreakDown(request: request, input: input, existing: existing)
		// Before it's sent, since the app may be closed before the server answers
		Defaults[.pendingBreakDown] = pending
		follow(pending)
	}

	/// A long text goes in parts, one after another. A part the validator turns down has nothing worth breaking down.
	private func startParts(of english: String) {
		let requests = TextParts.split(english)
			.filter { EnglishValidator.problem(with: $0) == nil }
			.map { account.breakDownRequest(english: $0, descriptors: LogicLetters.emptyDescriptors) }
		guard let first = requests.first else {
			run = .failed(ServiceError(code: .invalidRequest, message: "Expected some text to break down, found none that could be"))
			return
		}

		let parts = PendingBreakDown.Parts(whole: english, total: requests.count, waiting: Array(requests.dropFirst()))
		let pending = PendingBreakDown(request: first, input: input, existing: existing, parts: parts)
		Defaults[.pendingBreakDown] = pending
		follow(pending)
	}

	/// Keeps a finished part, and moves on to the next one if there is one. True when there was, so `follow` has more to do.
	private func advance(_ pending: PendingBreakDown, with result: ArgumentBreakdown) -> Bool {
		guard var parts = pending.parts else { return false }
		parts.finished.append(.init(text: pending.request.english, breakdown: result))

		var next = pending
		next.parts = parts
		guard let request = parts.waiting.first else {
			Defaults[.pendingBreakDown] = next
			finish(parts)
			return true
		}
		next.request = request
		next.parts?.waiting.removeFirst()
		Defaults[.pendingBreakDown] = next
		follow(next)
		return true
	}

	/// Everything's been broken down, which the app remembers until it's created or thrown away
	private func finish(_ parts: PendingBreakDown.Parts) {
		partProgress = nil
		let results = parts.finished.filter(\.hasResult)
		if let first = results.first {
			finishedParts = results
			run = .finished(first.breakdown)
		} else {
			// Only issues to show, with the text still editable
			Defaults[.pendingBreakDown] = nil
			run = parts.finished.last.map { .finished($0.breakdown) } ?? .idle
		}
	}

	/// Hears the pending breakdown, from the start. The server keeps going if the connection drops, so that is tried
	/// again a few times before giving up.
	func follow(_ pending: PendingBreakDown) {
		if let parts = pending.parts {
			// Found again after every part was done, when asking would only count the last one twice
			guard !parts.isDone else {
				finish(parts)
				return
			}
			partProgress = "Part \(parts.finished.count + 1) of \(parts.total)"
		}

		let request = pending.request
		let task = Task {
			do {
				var attempts = 0
				var result: ArgumentBreakdown
				while true {
					do {
						result = try await account.breakDown(request) { event in
							guard !Task.isCancelled else { return }
							run.apply(event)
						}
						break
					} catch let lost as TranslationAccount.ConnectionLost {
						attempts += 1
						guard attempts <= Self.reconnectAttempts else { throw lost.underlying }
						try await Task.sleep(for: .seconds(min(attempts * 2, 10)))
						// It says everything again from the start
						run.restartProgress()
					}
				}
				guard !Task.isCancelled else { return }
				if advance(pending, with: result) {
					return
				}
				if result.premises.isEmpty, result.conclusion.isEmpty {
					// Only issues to show, with the text still editable
					Defaults[.pendingBreakDown] = nil
				}
				run = .finished(result)
			} catch {
				guard !Task.isCancelled, !(error is CancellationError) else { return }
				Defaults[.pendingBreakDown] = nil
				run = .failed(
					error as? ServiceError
						?? ServiceError(code: .internalError, message: error.localizedDescription)
				)
			}
		}
		run = .running(TranslationProgress(), task)
	}

	static let reconnectAttempts = 5

	/// Tells the server to stop too, if it can be reached
	func stop() {
		run.cancel()
		Defaults[.pendingBreakDown] = nil
	}

	// MARK: - Creating

	/// Closes the boards sheet too, since the new board is what's open now
	func create() {
		guard let found else { return }
		Defaults[.pendingBreakDown] = nil
		if !finishedParts.isEmpty {
			createFromParts()
			navigation.reveal(.board)
			return
		}
		if let existing, boardStore.source(existing) != nil {
			boardStore.breakDown(found, into: existing)
		} else {
			boardStore.newBoard(from: found, source: input ?? .text(english.trimmingCharacters(in: .whitespacesAndNewlines)))
		}
		navigation.reveal(.board)
	}

	/// The first part goes where a single breakdown would. Each of the others gets a source and a region of its own on that board.
	private func createFromParts() {
		guard let first = finishedParts.first else { return }
		if let existing, boardStore.source(existing) != nil {
			boardStore.breakDown(first.breakdown, into: existing)
		} else {
			boardStore.newBoard(from: first.breakdown, source: input ?? .text(first.text))
		}
		for part in finishedParts.dropFirst() {
			let source = boardStore.addSource(.text(part.text), at: .zero)
			boardStore.breakDown(part.breakdown, into: source)
		}
	}
}
