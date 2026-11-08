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

		let english = english
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

	/// Hears the pending breakdown, from the start. The server keeps going if the connection drops, so that is tried
	/// again a few times before giving up.
	func follow(_ pending: PendingBreakDown) {
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
		if let existing, boardStore.source(existing) != nil {
			boardStore.breakDown(found, into: existing)
		} else {
			boardStore.newBoard(from: found, source: input ?? .text(english.trimmingCharacters(in: .whitespacesAndNewlines)))
		}
		navigation.selectedTab = .board
		navigation.dismissSheet()
	}
}
