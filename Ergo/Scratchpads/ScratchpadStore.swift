//
//  ScratchpadStore.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
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
		scratchpads.removeAll { ids.contains($0.id) }
		deletedIDs.formUnion(ids)
		if let currentID, ids.contains(currentID) {
			newScratchpad()
		}
		save()
	}

	// MARK: - translating

	/// Records a finished translation on the current scratchpad, whose English must still be `english`.
	/// The logic and descriptors only change when it produced logic; the caller has already parsed that. A failed
	/// translation only brings issues, and the logic that was there stays.
	func applyTranslation(_ translation: Translation, english: String) {
		var scratchpad = current
		guard scratchpad.english == english else { return }

		// Keyed to the English as sent, so the scratchpad never thinks it's out of date
		scratchpad.translation = Translation(
			english: english,
			entries: translation.entries,
			descriptors: translation.descriptors,
			issues: translation.issues
		)
		scratchpad.source = .english
		if !translation.entries.isEmpty {
			scratchpad.logic = translation.entries
			scratchpad.merge(descriptors: translation.descriptors)
		}
		current = scratchpad
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
