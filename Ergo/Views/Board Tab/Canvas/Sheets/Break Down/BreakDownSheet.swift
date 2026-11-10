//
//  BreakDownSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoTranslation
import SwiftUI

/// Pastes English and lets the server split it into premises and a conclusion, with no logic written. What it finds becomes
/// statements joined by arrows, in a region on the source they came from: a new board (`BoardStore.newBoard(from:source:)`),
/// or the current one when it's one of its sources being broken down. The claims it names are dropped, since a board holds English only.
///
/// The server does the work, and carries on if the app is closed. `Defaults[.pendingBreakDown]` is how it's found again: a
/// sheet for the same input asks for the same run, and hears its result from the start. It stays until the breakdown is
/// created, cancelled or edited, so a result worth a model call isn't lost to a force quit.
struct BreakDownSheet: View {
	@Environment(\.dismiss)
	var dismiss

	@Environment(NavigationManager.self)
	var navigation

	@Environment(BoardStore.self)
	var boardStore

	@Environment(TranslationAccount.self)
	var account

	@State var english: String
	@FocusState var englishFocused: Bool

	/// Finished holds what the server found, until you go back to edit the text
	@State var run = TranslationRun<ArgumentBreakdown>.idle

	/// A long text's parts, once they've all been broken down
	@State var finishedParts: [PendingBreakDown.Parts.Finished] = []

	/// Which part of a long text is being worked on, like "Part 2 of 5"
	@State var partProgress: String?

	/// Text from the share sheet starts on its own, since breaking it down is what was chosen
	let startsOnAppear: Bool

	/// What the new board's source is. The text itself when it's nil.
	let input: BoardSource.Content?

	/// The source on the current board that this is a breakdown of
	let existing: BoardSource.ID?

	init(shared: String? = nil, input: BoardSource.Content? = nil, existing: BoardSource.ID? = nil) {
		_english = State(initialValue: shared ?? "")
		self.input = input
		self.existing = existing
		startsOnAppear = shared.map { $0.count <= EnglishValidator.characterLimit } ?? false
	}

	/// The breakdown that was running when the app was closed
	init(resuming pending: PendingBreakDown) {
		_english = State(initialValue: pending.text)
		input = pending.input
		existing = pending.existing
		startsOnAppear = false
	}

	/// How far over the limit the text is, nil when it fits. A shared page usually is, and which part matters is the person's call.
	var overLimit: Int? {
		let count = english.trimmingCharacters(in: .whitespacesAndNewlines).count
		return count > EnglishValidator.characterLimit ? count : nil
	}

	/// A breakdown with nothing in it only has issues to show, so the text stays editable
	var found: ArgumentBreakdown? {
		guard let breakdown = run.output, !breakdown.premises.isEmpty || !breakdown.conclusion.isEmpty else { return nil }
		return breakdown
	}

	var canBreakDown: Bool {
		!english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	/// How many parts a text over the limit would go in. Nil when it fits, or is too long even for that.
	var partCount: Int? {
		guard overLimit != nil else { return nil }
		let count = TextParts.split(english).count
		return count <= TextParts.limit ? count : nil
	}

	/// Over the limit and able to go in parts, or within it
	var canStart: Bool {
		canBreakDown && (overLimit == nil || (partCount != nil && account.hasPlusFeatures))
	}

	var body: some View {
		NavigationStack {
			ZStack {
				if !finishedParts.isEmpty {
					BreakdownPartsView(parts: finishedParts)
				} else if let found {
					BreakdownResultView(
						breakdown: found,
						application: application(of: found)
					)
				} else {
					inputForm
				}
			}
			.animation(.smooth, value: found != nil)
			.toolbarTitleDisplayMode(.inline)
			.navigationTitle("Break Down")
			.toolbar { toolbar }
		}
		.presentationDetents([.large])
		.presentationDragIndicator(.visible)
		// A result is worth a model call, so swiping the sheet away doesn't throw it out. Cancel does.
		.interactiveDismissDisabled(run.isRunning || found != nil)
		// Leaving the tab only hides the sheet, and coming back finds the same run
		.onDisappear {
			if navigation.boardSheet == nil {
				stop()
			}
		}
		.task {
			guard !run.isRunning, run.output == nil, run.failure == nil else { return }
			if let pending = Defaults[.pendingBreakDown], pending.matches(english: english, input: input, existing: existing) {
				// Still going on the server, or finished while the app was closed
				english = pending.text
				follow(pending)
			} else if startsOnAppear {
				startBreakDown()
			}
		}
	}

	/// What creating would do to the board it goes on, for saying what won't fit
	func application(of found: ArgumentBreakdown) -> ArgumentBreakdownApplication<Statement, Link> {
		guard existing != nil else {
			return found.applied(to: Board().map, replacing: true)
		}
		let board = boardStore.current
		return found.applied(to: board.map, replacing: board.hasOnlyPlaceholder)
	}

	// MARK: - Parts

	var inputForm: some View {
		BreakDownInputForm(
			english: $english,
			focused: $englishFocused,
			run: run,
			setUp: setUp,
			overLimit: overLimit,
			parts: partCount,
			partProgress: partProgress,
			seePlus: overLimit != nil && !account.hasPlusFeatures ? { navigation.presentSheet(.plus) } : nil,
			canBreakDown: canStart,
			breakDown: startBreakDown,
			stop: stop
		)
	}

	var toolbar: some ToolbarContent {
		BreakDownToolbar(
			hasResult: found != nil,
			focused: $englishFocused,
			cancel: {
				stop()
				dismiss()
			},
			editText: {
				Defaults[.pendingBreakDown] = nil
				finishedParts = []
				run = .idle
			},
			create: create
		)
	}

	/// Only for errors fixed by connecting a provider in Settings
	var setUp: (() -> Void)? {
		switch run.failure?.code {
			case .notConnected, .credentialRejected:
				openSettings
			default:
				nil
		}
	}

	func openSettings() {
		navigation.presentSheet(.settings(id: "3refd"))
	}
}

// MARK: - Resuming

/// The breakdown that was running when the app was closed, found again from `Defaults[.pendingBreakDown]`
struct ResumedBreakDownSheet: View {
	@Environment(NavigationManager.self)
	var navigation

	var body: some View {
		if let pending = Defaults[.pendingBreakDown] {
			BreakDownSheet(resuming: pending)
		} else {
			// Finished with, on another launch or by cancelling
			Color.clear
				.onAppear {
					navigation.dismissSheet()
				}
		}
	}
}
