//
//  PageStore.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import ErgoTranslation
import SwiftUI

/// Every page, and which one the Check tab is showing. Shared so the pages list
/// and the letters sheet edit the same page the editor does.
///
/// Statements and links are edited on the current page through the methods under "statements" and "links". Each
/// one bumps `modified` and goes through `current`, so it's saved after a pause and reported to sync with the page.
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

	// MARK: - statements

	/// The statement on the current page, nil once it's gone (deleted here or on another device)
	func statement(_ id: Statement.ID) -> Statement? {
		current.statement(id)
	}

	/// Reads and writes one statement of the current page. If the statement goes away while a view still holds the
	/// binding, reads give the last value it had and writes are dropped, so a view never crashes on a deleted box.
	func binding(for id: Statement.ID) -> Binding<Statement>? {
		guard let last = statement(id) else { return nil }
		return Binding(
			get: { [self] in statement(id) ?? last },
			set: { [self] in updateStatement($0) }
		)
	}

	/// Adds a statement to the current page, nil when the page is full (`ArgumentMapValidator.defaultMaximumStatements`).
	/// It goes in a free spot beside `anchor` (`side` says which: `.left` for a premise, `.right` for a conclusion,
	/// `.below` for a sibling), or beside the origin without one. Text given makes it start with that content.
	@discardableResult
	func addStatement(
		english: String = "",
		logic: [LogicKeyboardEntry] = [],
		near anchor: Statement.ID? = nil,
		side: CanvasLayout.Side = .left
	) -> Statement.ID? {
		var page = current
		guard page.statements.count < ArgumentMapValidator.defaultMaximumStatements else { return nil }

		let position = if let anchor {
			CanvasLayout.place(newNodeNear: anchor, in: page.map, side: side)
		} else {
			CanvasLayout.place(near: .zero, side: side, occupied: page.statements.map(\.position))
		}
		var statement = Statement(position: position, english: english, logic: logic)
		if !english.isEmpty, logic.isEmpty {
			statement.source = .english
		}
		page.statements.append(statement)
		current = page
		return statement.id
	}

	/// Adds a statement with its centre at `position`, for the canvas dropping one where the person is looking.
	/// Nil when the page is full.
	@discardableResult
	func addStatement(english: String = "", at position: CanvasPoint) -> Statement.ID? {
		var page = current
		guard page.statements.count < ArgumentMapValidator.defaultMaximumStatements else { return nil }

		var statement = Statement(position: position, english: english)
		if !english.isEmpty {
			statement.source = .english
		}
		page.statements.append(statement)
		current = page
		return statement.id
	}

	/// Replaces the statement with the same id. Typing goes through here, so one that changes nothing is skipped.
	func updateStatement(_ statement: Statement) {
		var page = current
		guard let index = page.statements.firstIndex(where: { $0.id == statement.id }), page.statements[index] != statement else { return }
		page.statements[index] = statement
		current = page
	}

	/// Sets the centre of the box. Call it when a drag ends: sync writes the position as its own field, and every call restarts the save timer.
	func moveStatement(id: Statement.ID, to position: CanvasPoint) {
		var page = current
		guard let index = page.statements.firstIndex(where: { $0.id == id }), page.statements[index].position != position else { return }
		page.statements[index].position = position
		current = page
	}

	/// Deletes the statement and the links that touch it. The last statement is replaced with an empty one in the same
	/// place, since a page is never without one.
	func deleteStatement(id: Statement.ID) {
		var page = current
		guard let index = page.statements.firstIndex(where: { $0.id == id }) else { return }
		let position = page.statements[index].position
		page.statements.remove(at: index)
		page.links.removeAll { $0.premise == id || $0.conclusion == id }
		if page.statements.isEmpty {
			page.statements = [Statement(position: position)]
		}
		current = page
	}

	// MARK: - links

	/// Draws an arrow from `premise` to `conclusion`. Nothing is added when it would be wrong (the same arrow twice,
	/// a statement to itself, a loop), and the reason comes back; its `message` is worded for showing.
	@discardableResult
	func link(premise: Statement.ID, conclusion: Statement.ID) -> ArgumentMapProblem? {
		var page = current
		let link = Link(premise: premise, conclusion: conclusion)
		if let problem = ArgumentMapValidator.problem(adding: link, to: page.map) {
			return problem
		}
		page.links.append(link)
		current = page
		return nil
	}

	func unlink(id: Link.ID) {
		var page = current
		guard page.links.contains(where: { $0.id == id }) else { return }
		page.links.removeAll { $0.id == id }
		current = page
	}

	// MARK: - arranging

	/// Lays every statement out again (`CanvasLayout.arranged`)
	func arrange() {
		var page = current
		let map = CanvasLayout.arranged(page.map)
		guard map.statements != page.statements else { return }
		page.map = map
		current = page
	}

	// MARK: - text

	/// Edits the whole page as text, one statement a line: `ArgumentText.apply`. Lines that didn't change keep their
	/// statement, position and links. New ones are added and linked as premises of the conclusion, removed ones are deleted.
	///
	/// A statement the text edited gets `source` for the kind written, loses its translation, and for logic gets its
	/// English written back when the logic parses, as in the editor. Nothing changes when it throws.
	@discardableResult
	func applyText(_ text: String, kind: ArgumentTextKind) throws(ArgumentTextProblem) -> ArgumentTextChange<Statement, Link> {
		var page = current
		let letters = LogicLetters.resolved(Defaults[.logicLetters])
		var change = try ArgumentText.apply(text: text, kind: kind, letters: letters, to: page.map)

		for index in change.map.statements.indices {
			let id = change.map.statements[index].id
			guard change.added.contains(id) || change.edited.contains(id) else { continue }

			change.map.statements[index].translation = nil
			switch kind {
				case .english:
					change.map.statements[index].source = .english
				case .logic:
					change.map.statements[index].source = .logic
					if let english = Self.english(of: change.map.statements[index].logic, letters: letters, descriptors: page.descriptors) {
						change.map.statements[index].english = english
					}
			}
		}

		page.map = change.map
		current = page
		return change
	}

	/// The English for logic that parses cleanly, nil for logic that's empty or half written
	private static func english(of logic: [LogicKeyboardEntry], letters: [String], descriptors: [String]) -> String? {
		guard !logic.isEmpty else { return nil }
		let parse = LogicParser.parse(logic)
		guard parse.diagnostics.isEmpty else { return nil }
		return LogicEnglish.text(for: parse.argument, letters: letters, descriptors: descriptors)
	}

	// MARK: - checking

	/// What the checker makes of the statement as the conclusion of its premises. Nil when it has no premises, or it or
	/// one of them has no logic yet; the failure says why a statement can't be checked (`ArgumentEntriesProblem.message`).
	/// A statement on its own is checked by `LogicChecker.analyze(statement.logic)`, as the editor does.
	func check(_ id: Statement.ID) -> Result<LogicAnalysis?, ArgumentEntriesProblem> {
		Result { () throws(ArgumentEntriesProblem) in
			try ArgumentEntries.check(statement: id, in: current.map)
		}
	}

	/// `check` without the reason
	func analysis(for id: Statement.ID) -> LogicAnalysis? {
		(try? check(id).get()) ?? nil
	}

	// MARK: - translating

	/// Gives the page the names for letters that a translation or breakdown found, in slots still free
	func mergeDescriptors(_ descriptors: [String]) {
		var page = current
		let before = page.descriptors
		page.merge(descriptors: descriptors)
		guard page.descriptors != before else { return }
		current = page
	}

	/// Records a finished translation on the statement it was for, whose English must still be `english`.
	/// The logic and descriptors only change when it produced logic; the caller has already parsed that. A failed
	/// translation only brings issues, and the logic that was there stays.
	func applyTranslation(_ translation: Translation, english: String, to id: Statement.ID) {
		var page = current
		guard let index = page.statements.firstIndex(where: { $0.id == id }), page.statements[index].english == english else { return }

		// Keyed to the English as sent, so the statement never thinks it's out of date
		page.statements[index].translation = Translation(
			english: english,
			entries: translation.entries,
			descriptors: translation.descriptors,
			issues: translation.issues
		)
		page.statements[index].source = .english
		if !translation.entries.isEmpty {
			page.statements[index].logic = translation.entries
			page.merge(descriptors: translation.descriptors)
		}
		current = page
	}

	// MARK: - breaking down

	/// Puts a server breakdown on the current page: a statement per premise and one for the conclusion, every premise linked
	/// to it (`ArgumentBreakdown.applied`). Adding lays the new statements out under what's there without moving it;
	/// replacing drops every statement and link and lays the page out again. The breakdown's claims fill the page's free
	/// descriptor slots. Statements past the limit are left out, and the result says how many.
	///
	/// New statements start as English with nothing translated, like any typed statement. Nothing changes when nothing is added.
	@discardableResult
	func applyBreakdown(_ breakdown: ArgumentBreakdown, replacing: Bool) -> ArgumentBreakdownApplication<Statement, Link> {
		var page = current
		var application = breakdown.applied(to: page.map, replacing: replacing)
		guard !application.added.isEmpty else { return application }

		for index in application.map.statements.indices where application.added.contains(application.map.statements[index].id) {
			application.map.statements[index].source = .english
		}
		page.map = application.map
		page.merge(descriptors: breakdown.descriptors)
		current = page
		return application
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
				// Only the stamps moving isn't an edit
				var old = pages[index]
				old.modified = page.modified
				if old != page, page.id == currentID {
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

	/// A statement holding what lost a simultaneous edit on another device, on the page it was edited on.
	/// It syncs like any new statement, and isn't held to the statement limit, since nothing may be lost.
	func insertStatementCopy(_ statement: Statement, into pageID: LogicPage.ID) {
		guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
		pages[index].statements.append(statement)
		pages[index].modified = .now
		changedIDs.insert(pageID)
		save()
	}
}
