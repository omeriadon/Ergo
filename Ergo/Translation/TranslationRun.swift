//
//  TranslationRun.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoProtocol
import ErgoTranslation
import Foundation

/// Where one run of the server's translation stands. A screen holds one of these instead of a flag, a progress,
/// an error and a result that could disagree. `Output` is what a finished run hands back, `Never` when
/// the result goes straight onto the board and the run returns to `.idle`.
enum TranslationRun<Output: Hashable>: Hashable {
	case idle

	/// The task is kept so stopping can cancel it
	case running(TranslationProgress, Task<Void, Never>)

	case failed(ServiceError)
	case finished(Output)

	/// Nil unless running
	var progress: TranslationProgress? {
		guard case let .running(progress, _) = self else { return nil }
		return progress
	}

	var failure: ServiceError? {
		guard case let .failed(error) = self else { return nil }
		return error
	}

	var output: Output? {
		guard case let .finished(output) = self else { return nil }
		return output
	}

	var isRunning: Bool {
		progress != nil
	}

	/// Late events of a run that's over change nothing
	mutating func apply(_ event: TranslationEvent) {
		guard case .running(var progress, let task) = self else { return }
		progress.apply(event)
		self = .running(progress, task)
	}

	/// Closing the socket makes the server stop too. A run that's over keeps what it ended with.
	mutating func cancel() {
		guard case let .running(_, task) = self else { return }
		task.cancel()
		self = .idle
	}
}
