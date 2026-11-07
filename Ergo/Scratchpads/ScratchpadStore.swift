//
//  ScratchpadStore.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import SwiftUI

/// Every scratchpad, and which one the Logic tab's editor is showing. Shared so the list and the editor edit
/// the same scratchpad, and so is the letters sheet.
///
/// Every change goes through `current`, so it's saved after a pause and reported to sync.
@MainActor
@Observable
final class ScratchpadStore {
	// MARK: - scratchpads

	private(set) var scratchpads: [LogicScratchpad]

	/// Newest first
	var sortedScratchpads: [LogicScratchpad] {
		scratchpads.sorted { $0.modified > $1.modified }
	}

	// MARK: - current

	private(set) var currentID: LogicScratchpad.ID? {
		didSet {
			Defaults[.currentScratchpadID] = currentID
		}
	}

	/// Stays out of the list until something's written on it
	private var draft = LogicScratchpad()

	var current: LogicScratchpad {
		get {
			scratchpads.first { $0.id == currentID } ?? draft
		}
		set {
			var scratchpad = newValue
			scratchpad.modified = .now

			if let index = scratchpads.firstIndex(where: { $0.id == scratchpad.id }) {
				scratchpads[index] = scratchpad
				changedIDs.insert(scratchpad.id)
			} else if scratchpad.isEmpty {
				draft = scratchpad
			} else {
				scratchpads.append(scratchpad)
				changedIDs.insert(scratchpad.id)
				currentID = scratchpad.id
			}

			scheduleSave()
		}
	}

	/// Goes up when another device changes the open scratchpad, so the editor can drop a selection that no longer fits
	private(set) var remoteEdits = 0

	@ObservationIgnored
	private var saveTask: Task<Void, Never>?

	init() {
		scratchpads = Defaults[.scratchpads]
		currentID = Defaults[.currentScratchpadID]
	}

	// MARK: - newScratchpad

	func newScratchpad() {
		discardCurrentIfEmpty()
		draft = LogicScratchpad()
		currentID = nil
	}

	// MARK: - open

	func open(_ id: LogicScratchpad.ID) {
		guard id != currentID else { return }
		discardCurrentIfEmpty()
		currentID = id
	}

	// MARK: - delete

	func delete(_ ids: Set<LogicScratchpad.ID>) {
		ids.forEach(stopTranslating)
		scratchpads.removeAll { ids.contains($0.id) }
		deletedIDs.formUnion(ids)
		if let currentID, ids.contains(currentID) {
			newScratchpad()
		}
		save()
	}

	// MARK: - translating

	/// One per scratchpad that's translating or just failed. They're kept here and not on the editor, so a translation
	/// carries on while you're on another tab or another scratchpad, and only the stop button ends it.
	private var runs: [LogicScratchpad.ID: TranslationRun<Never>] = [:]

	func run(for id: LogicScratchpad.ID) -> TranslationRun<Never> {
		runs[id] ?? .idle
	}

	func translate(_ id: LogicScratchpad.ID, letters: [String], account: TranslationAccount) {
		guard let scratchpad = scratchpad(id) else { return }
		let (english, descriptors) = (scratchpad.english, scratchpad.descriptors)
		runs[id] = nil

		// Obviously bad input never reaches the server, and reads like any other translation issue
		if let problem = EnglishValidator.problem(with: english) {
			finish(id, with: Translation(english: english, issues: [TranslationIssue(severity: .error, message: problem)]), english: english)
			return
		}

		let task = Task {
			do {
				let translation = try await account.translate(english: english, letters: letters, descriptors: descriptors) { event in
					guard !Task.isCancelled else { return }
					runs[id]?.apply(event)
				}
				guard !Task.isCancelled else { return }
				runs[id] = nil

				// Never trust the server's logic blindly
				guard LogicParser.parse(translation.entries).diagnostics.isEmpty else {
					runs[id] = .failed(ServiceError(code: .internalError, message: "Server sent logic that doesn't parse"))
					return
				}
				finish(id, with: translation, english: english)
			} catch {
				guard !Task.isCancelled, !(error is CancellationError) else { return }
				runs[id] = .failed(
					error as? ServiceError
						?? ServiceError(code: .internalError, message: error.localizedDescription)
				)
			}
		}
		runs[id] = .running(TranslationProgress(), task)
	}

	/// Closing the socket makes the server stop too
	func stopTranslating(_ id: LogicScratchpad.ID) {
		runs[id]?.cancel()
		runs[id] = nil
	}

	/// A failure says nothing about English that has since changed. One that's running carries on.
	func clearFailure(_ id: LogicScratchpad.ID) {
		if runs[id]?.failure != nil {
			runs[id] = nil
		}
	}

	/// The English must still be what was sent, or the scratchpad has moved on and this says nothing about it.
	/// The logic and descriptors only change when it produced logic. A failed translation only brings issues, and the
	/// logic that was there stays.
	private func finish(_ id: LogicScratchpad.ID, with translation: Translation, english: String) {
		guard let index = scratchpads.firstIndex(where: { $0.id == id }), scratchpads[index].english == english else { return }

		// Keyed to the English as sent, so the scratchpad never thinks it's out of date
		scratchpads[index].translation = Translation(
			english: english,
			entries: translation.entries,
			descriptors: translation.descriptors,
			issues: translation.issues
		)
		scratchpads[index].source = .english
		if !translation.entries.isEmpty {
			scratchpads[index].logic = translation.entries
			scratchpads[index].merge(descriptors: translation.descriptors)
		}
		scratchpads[index].modified = .now
		changedIDs.insert(id)
		scheduleSave()
	}

	private func scratchpad(_ id: LogicScratchpad.ID) -> LogicScratchpad? {
		scratchpads.first { $0.id == id }
	}

	// MARK: - save

	/// What changed since the last save, for sync
	@ObservationIgnored
	private var changedIDs: Set<LogicScratchpad.ID> = []

	@ObservationIgnored
	private var deletedIDs: Set<LogicScratchpad.ID> = []

	/// Hears every save with the scratchpads that changed and the ones deleted. Remote changes aren't passed back.
	@ObservationIgnored
	var didSave: ((_ changed: [LogicScratchpad], _ deleted: Set<LogicScratchpad.ID>) -> Void)?

	/// Typing changes the scratchpad on every keystroke, so writes wait for a pause
	private func scheduleSave() {
		saveTask?.cancel()
		saveTask = Task {
			try? await Task.sleep(for: .seconds(1))
			guard !Task.isCancelled else { return }
			save()
		}
	}

	func save() {
		saveTask?.cancel()
		Defaults[.scratchpads] = scratchpads

		let changed = scratchpads.filter { changedIDs.contains($0.id) }
		let deleted = deletedIDs
		changedIDs = []
		deletedIDs = []
		if !changed.isEmpty || !deleted.isEmpty {
			didSave?(changed, deleted)
		}
	}

	/// For leaving the editor: a scratchpad that's been emptied goes, like a board does
	func discardCurrentIfEmpty() {
		guard let currentID, current.isEmpty else { return }
		stopTranslating(currentID)
		scratchpads.removeAll { $0.id == currentID }
		deletedIDs.insert(currentID)
		self.currentID = nil
		draft = LogicScratchpad()
		save()
	}

	// MARK: - sync

	/// Writes what other devices changed. Keeps their `modified`, and doesn't report it back as a local change.
	func applyRemote(_ remote: [LogicScratchpad], deleted: Set<LogicScratchpad.ID>) {
		guard !remote.isEmpty || !deleted.isEmpty else { return }

		for scratchpad in remote {
			if let index = scratchpads.firstIndex(where: { $0.id == scratchpad.id }) {
				// Only the stamps moving isn't an edit
				var old = scratchpads[index]
				old.modified = scratchpad.modified
				if old != scratchpad, scratchpad.id == currentID {
					remoteEdits += 1
				}
				scratchpads[index] = scratchpad
			} else {
				scratchpads.append(scratchpad)
			}
		}
		deleted.forEach(stopTranslating)
		scratchpads.removeAll { deleted.contains($0.id) }

		// Deleted on another device, so it goes the same way as deleting it here
		if let currentID, deleted.contains(currentID) {
			draft = LogicScratchpad()
			self.currentID = nil
		}

		Defaults[.scratchpads] = scratchpads
	}

	/// A scratchpad holding what lost a simultaneous edit on another device, beside the one that won.
	/// It syncs like any new scratchpad.
	func insertCopy(_ scratchpad: LogicScratchpad) {
		scratchpads.append(scratchpad)
		changedIDs.insert(scratchpad.id)
		save()
	}
}
