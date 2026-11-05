//
//  PageStore.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import SwiftUI

/// Every page, and which one the Check tab is showing. Shared so the pages list
/// and the letters sheet edit the same page the editor does.
@MainActor
@Observable
final class PageStore {
	// MARK: - pages

	private(set) var pages: [LogicPage]

	/// Newest first
	var sortedPages: [LogicPage] {
		pages.sorted { $0.modified > $1.modified }
	}

	// MARK: - current

	private(set) var currentID: LogicPage.ID? {
		didSet {
			Defaults[.currentPageID] = currentID
		}
	}

	/// Stays out of the list until something's written on it
	private var draft = LogicPage()

	var current: LogicPage {
		get {
			pages.first { $0.id == currentID } ?? draft
		}
		set {
			var page = newValue
			page.modified = .now

			if let index = pages.firstIndex(where: { $0.id == page.id }) {
				pages[index] = page
				changedIDs.insert(page.id)
			} else if page.isEmpty {
				draft = page
			} else {
				pages.append(page)
				changedIDs.insert(page.id)
				currentID = page.id
			}

			scheduleSave()
		}
	}

	/// Goes up when another device changes the open page, so the editor can drop a selection that no longer fits
	private(set) var remoteEdits = 0

	@ObservationIgnored
	private var saveTask: Task<Void, Never>?

	init() {
		pages = Defaults[.pages]
		currentID = Defaults[.currentPageID]
	}

	// MARK: - newPage

	func newPage() {
		discardCurrentIfEmpty()
		draft = LogicPage()
		currentID = nil
	}

	// MARK: - open

	func open(_ id: LogicPage.ID) {
		guard id != currentID else { return }
		discardCurrentIfEmpty()
		currentID = id
	}

	// MARK: - delete

	func delete(_ ids: Set<LogicPage.ID>) {
		pages.removeAll { ids.contains($0.id) }
		deletedIDs.formUnion(ids)
		if let currentID, ids.contains(currentID) {
			newPage()
		}
		save()
	}

	// MARK: - save

	/// What changed since the last save, for sync
	@ObservationIgnored
	private var changedIDs: Set<LogicPage.ID> = []

	@ObservationIgnored
	private var deletedIDs: Set<LogicPage.ID> = []

	/// Hears every save with the pages that changed and the ones deleted. Remote changes aren't passed back.
	@ObservationIgnored
	var didSave: ((_ changed: [LogicPage], _ deleted: Set<LogicPage.ID>) -> Void)?

	/// Typing changes the page on every keystroke, so writes wait for a pause
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
		Defaults[.pages] = pages

		let changed = pages.filter { changedIDs.contains($0.id) }
		let deleted = deletedIDs
		changedIDs = []
		deletedIDs = []
		if !changed.isEmpty || !deleted.isEmpty {
			didSave?(changed, deleted)
		}
	}

	private func discardCurrentIfEmpty() {
		guard let currentID, current.isEmpty else { return }
		pages.removeAll { $0.id == currentID }
		deletedIDs.insert(currentID)
		save()
	}

	// MARK: - sync

	/// Writes what other devices changed. Keeps their `modified`, and doesn't report it back as a local change.
	func applyRemote(_ remote: [LogicPage], deleted: Set<LogicPage.ID>) {
		guard !remote.isEmpty || !deleted.isEmpty else { return }

		for page in remote {
			if let index = pages.firstIndex(where: { $0.id == page.id }) {
				if pages[index] != page, page.id == currentID {
					remoteEdits += 1
				}
				pages[index] = page
			} else {
				pages.append(page)
			}
		}
		pages.removeAll { deleted.contains($0.id) }

		// Deleted on another device, so it goes the same way as deleting it here
		if let currentID, deleted.contains(currentID) {
			draft = LogicPage()
			self.currentID = nil
		}

		Defaults[.pages] = pages
	}

	/// A new page holding what lost a simultaneous edit on another device. It syncs like any page.
	func insertCopy(_ page: LogicPage) {
		pages.append(page)
		changedIDs.insert(page.id)
		save()
	}
}
