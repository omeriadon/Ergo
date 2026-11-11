//
//  CleanDefaults.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
@testable import Ergo
import Foundation
import Testing

/// Gives every test an empty `UserDefaults.standard`, and puts the simulator's own back afterwards.
///
/// The app saves everything through Defaults, and the tests run inside the app on a real simulator, so without this a test
/// would read whatever boards and chats were left there, and leave its own behind. Put it on a suite, then write tests as if
/// the app were freshly installed:
///
///     @Suite(.cleanDefaults)
///     struct MyStoreTests { ... }
///
/// Only the keys in `TestDefaults.keys` are touched, never the server or the sign-in. Tests that use it also wait for each
/// other, since the keys are shared.
nonisolated struct CleanDefaults: TestTrait, SuiteTrait, TestScoping {
	var isRecursive: Bool {
		true
	}

	/// One at a time and only for a test case, so the suite's own scope doesn't wait for a test's
	func scopeProvider(for _: Test, testCase: Test.Case?) -> CleanDefaults? {
		testCase == nil ? nil : self
	}

	@concurrent
	func provideScope(for _: Test, testCase _: Test.Case?, performing function: @concurrent @Sendable () async throws -> Void) async throws {
		await Self.gate.enter()
		await MainActor.run { TestDefaults.begin() }

		var failure: (any Error)?
		do {
			try await function()
		} catch {
			failure = error
		}

		await MainActor.run { TestDefaults.end() }
		await Self.gate.leave()
		if let failure {
			throw failure
		}
	}

	/// Lets one test through at a time
	private static let gate = Gate()

	private actor Gate {
		private var isBusy = false
		private var waiting: [CheckedContinuation<Void, Never>] = []

		func enter() async {
			guard isBusy else {
				isBusy = true
				return
			}
			await withCheckedContinuation { waiting.append($0) }
		}

		func leave() {
			if waiting.isEmpty {
				isBusy = false
			} else {
				waiting.removeFirst().resume()
			}
		}
	}
}

nonisolated extension Trait where Self == CleanDefaults {
	/// Each test starts with empty Defaults, and the simulator's are put back after it
	static var cleanDefaults: CleanDefaults {
		CleanDefaults()
	}
}

/// What `CleanDefaults` does before and after a test
enum TestDefaults {
	/// The keys the stores under test read and write. A store that starts using another key needs it added here, or a test
	/// of it would see the simulator's value, and leave its own behind.
	///
	/// Left out on purpose: the server and sign-in keys, since the app that is hosting the tests watches those and would
	/// sign out, and the synced settings and bookmarks, which it watches too.
	static let keys: [Defaults.Keys] = [
		.boards, .currentBoardID, .pinnedBoards, .archivedBoards,
		.scratchpads, .currentScratchpadID,
		.askConversations, .currentAskConversationID,
		.pendingBreakDown,
		.selectedTab, .libraryPath, .askThreadSelected, .logicPath, .libraryGeneralSearchText,
		.presentedSheet, .boardSheet, .logicSheet, .librarySheet,
		.syncState, .syncDeviceID,
	]

	/// What was there before the test, as stored. A key that wasn't set isn't in here.
	private static var saved: [String: Any] = [:]

	private static var cleanups: [() -> Void] = []

	/// Runs when the test is over, before the simulator's Defaults come back. For stopping a store's delayed save, which
	/// would otherwise write a second later, into whatever the next test is doing.
	static func onFinish(_ cleanup: @escaping () -> Void) {
		cleanups.append(cleanup)
	}

	static func begin() {
		saved = [:]
		for key in keys {
			if let value = key.suite.object(forKey: key.name) {
				saved[key.name] = value
			}
			key.suite.removeObject(forKey: key.name)
		}
	}

	static func end() {
		let finishing = cleanups
		cleanups = []
		for cleanup in finishing {
			cleanup()
		}

		for key in keys {
			key.suite.removeObject(forKey: key.name)
			if let value = saved[key.name] {
				key.suite.set(value, forKey: key.name)
			}
		}
		saved = [:]
	}
}
