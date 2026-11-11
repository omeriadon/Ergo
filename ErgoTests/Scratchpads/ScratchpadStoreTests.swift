//
//  ScratchpadStoreTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
@testable import Ergo
import ErgoLogic
import ErgoSync
import Foundation
import Testing

/// The saved list of scratchpads on the Logic tab: what's open, what's kept and what goes to sync
@Suite(.cleanDefaults)
struct ScratchpadStoreTests {
	/// What the store told sync
	final class ScratchpadSaves {
		var changed: Set<UUID> = []
		var deleted: Set<UUID> = []
		var count = 0
	}

	func recordSaves(of store: ScratchpadStore) -> ScratchpadSaves {
		let log = ScratchpadSaves()
		store.didSave = { changed, deleted in
			log.changed.formUnion(changed.map(\.id))
			log.deleted.formUnion(deleted)
			log.count += 1
		}
		return log
	}

	// MARK: - Starting

	@Test func aNewStoreHasNoScratchpadsAndAnEmptyDraft() {
		let store = ScratchpadStore.test()

		#expect(store.scratchpads.isEmpty)
		#expect(store.currentID == nil)
		#expect(store.current.isEmpty)
	}

	@Test func theStoreOpensWithWhatWasSaved() {
		let saved = scratchpad("X→Y")
		let store = ScratchpadStore.test(saved)

		#expect(store.scratchpads.map(\.id) == [saved.id])
		#expect(store.current.id == saved.id)
		#expect(store.current.logic == saved.logic)
	}

	// MARK: - Writing

	@Test func writingLogicOnTheDraftAddsItToTheList() {
		let store = ScratchpadStore.test()
		var draft = store.current
		draft.logic = Logic.entries("X∧Y")

		store.current = draft

		#expect(store.scratchpads.count == 1)
		#expect(store.currentID == draft.id)
		#expect(Defaults[.currentScratchpadID] == draft.id)
	}

	/// Naming letters isn't writing, so the scratchpad stays out of the list
	@Test func namingLettersAloneLeavesTheDraftAsADraft() {
		let store = ScratchpadStore.test()
		var draft = store.current
		draft.descriptors[0] = "it rains"

		store.current = draft

		#expect(store.scratchpads.isEmpty)
		#expect(store.current.descriptors[0] == "it rains")
	}

	@Test func anEditUpdatesWhenItWasChanged() {
		var old = scratchpad("X→Y")
		old.modified = Date(timeIntervalSince1970: 100)
		let store = ScratchpadStore.test(old)
		var edited = store.current
		edited.logic = Logic.entries("X∧Y")

		store.current = edited

		#expect(store.current.modified > old.modified)
	}

	// MARK: - Saving

	@Test func savingWritesToDefaultsAndTellsSyncWhatChanged() {
		let saved = scratchpad("X→Y")
		let store = ScratchpadStore.test(saved)
		let log = recordSaves(of: store)
		var edited = store.current
		edited.logic = Logic.entries("X∧Y")
		edited.english = Logic.reading("X∧Y") ?? ""

		store.current = edited
		store.save()

		#expect(Defaults[.scratchpads].first?.english == "X and Y.")
		#expect(log.changed == [saved.id])
	}

	@Test func savingWithNothingNewTellsSyncNothing() {
		let store = ScratchpadStore.test(scratchpad("X→Y"))
		let log = recordSaves(of: store)

		store.save()

		#expect(log.count == 0)
	}

	@Test func englishAndLogicSurviveBeingSavedTogether() {
		let weather = ["it rains", "the ground is wet", "", "", "", ""]
		var written = scratchpad("X→Y,X∴Y")
		written.descriptors = weather
		written.english = Logic.reading("X→Y,X∴Y", descriptors: weather) ?? ""
		let store = ScratchpadStore.test()
		store.current = written
		store.save()

		let reopened = ScratchpadStore()

		#expect(reopened.scratchpads.first?.english == "If it rains, then the ground is wet.\nIt rains.\nTherefore, the ground is wet.")
		#expect(reopened.scratchpads.first?.logic == written.logic)
		#expect(reopened.scratchpads.first?.descriptors == weather)
	}

	// MARK: - Opening and leaving

	@Test func openingAnotherScratchpadRemembersIt() {
		let first = scratchpad("X→Y")
		let second = scratchpad("X∧Y")
		let store = ScratchpadStore.test(first, second)

		store.open(second.id)

		#expect(store.currentID == second.id)
		#expect(Defaults[.currentScratchpadID] == second.id)
	}

	@Test func aScratchpadEmptiedOutIsDiscardedWhenLeaving() {
		let kept = scratchpad("X→Y")
		let emptied = scratchpad("X∧Y")
		let store = ScratchpadStore.test(emptied, kept)
		let log = recordSaves(of: store)
		var blank = store.current
		blank.logic = []
		blank.english = ""
		store.current = blank

		store.discardCurrentIfEmpty()

		#expect(store.scratchpads.map(\.id) == [kept.id])
		#expect(store.currentID == nil)
		#expect(log.deleted == [emptied.id])
	}

	@Test func aScratchpadWithLogicIsKeptWhenLeaving() {
		let store = ScratchpadStore.test(scratchpad("X→Y"))

		store.discardCurrentIfEmpty()

		#expect(store.scratchpads.count == 1)
	}

	@Test func startingANewScratchpadDiscardsAnEmptyOneAndOpensADraft() {
		let store = ScratchpadStore.test(LogicScratchpad())

		store.newScratchpad()

		#expect(store.scratchpads.isEmpty)
		#expect(store.currentID == nil)
	}

	// MARK: - Renaming

	@Test func renamingTrimsAndAnEmptyNameGoesBackToTheWrittenTitle() {
		let pad = scratchpad("X→Y")
		let store = ScratchpadStore.test(pad)
		let letters = LogicLetters.defaults

		store.rename(pad.id, to: "  Modus ponens\n")
		#expect(store.current.title(letters: letters) == "Modus ponens")

		store.rename(pad.id, to: "")
		#expect(store.current.title(letters: letters) == "If X, then Y.")
	}

	@Test func renamingAScratchpadThatIsntThereDoesNothing() {
		let pad = scratchpad("X→Y")
		let store = ScratchpadStore.test(pad)

		store.rename(UUID(), to: "Lost")

		#expect(store.current.name.isEmpty)
	}

	// MARK: - Deleting

	@Test func deletingScratchpadsReportsThemAndForgetsThem() {
		let kept = scratchpad("X→Y")
		let doomed = scratchpad("X∧Y")
		let store = ScratchpadStore.test(kept, doomed)
		let log = recordSaves(of: store)

		store.delete([doomed.id])

		#expect(store.scratchpads.map(\.id) == [kept.id])
		#expect(log.deleted == [doomed.id])
		#expect(Defaults[.scratchpads].map(\.id) == [kept.id])
	}

	@Test func deletingTheOpenScratchpadStartsANewDraft() {
		let open = scratchpad("X→Y")
		let store = ScratchpadStore.test(open)

		store.delete([open.id])

		#expect(store.currentID == nil)
		#expect(store.current.isEmpty)
	}

	@Test func theListIsNewestFirst() {
		var old = scratchpad("X→Y")
		old.modified = Date(timeIntervalSince1970: 100)
		var new = scratchpad("X∧Y")
		new.modified = Date(timeIntervalSince1970: 200)
		let store = ScratchpadStore.test(old, new)

		#expect(store.sortedScratchpads.map(\.id) == [new.id, old.id])
	}

	// MARK: - From other devices

	@Test func remoteScratchpadsAreWrittenWithoutBeingReportedBack() {
		let store = ScratchpadStore.test()
		let log = recordSaves(of: store)
		let remote = scratchpad("X↔Y")

		store.applyRemote([remote], deleted: [])
		store.save()

		#expect(store.scratchpads.map(\.id) == [remote.id])
		#expect(Defaults[.scratchpads].map(\.id) == [remote.id])
		#expect(log.count == 0)
	}

	@Test func aRemoteChangeReplacesTheScratchpad() {
		let pad = scratchpad("X→Y")
		let store = ScratchpadStore.test(pad)
		var remote = pad
		remote.logic = Logic.entries("X∧Y")

		store.applyRemote([remote], deleted: [])

		#expect(store.current.logic == remote.logic)
	}

	@Test func aScratchpadDeletedElsewhereGoesAndTheOpenOneBecomesADraft() {
		let pad = scratchpad("X→Y")
		let store = ScratchpadStore.test(pad)

		store.applyRemote([], deleted: [pad.id])

		#expect(store.scratchpads.isEmpty)
		#expect(store.currentID == nil)
		#expect(store.current.isEmpty)
	}

	@Test func aConflictCopyIsKeptAndReported() {
		let pad = scratchpad("X→Y")
		let store = ScratchpadStore.test(pad)
		let log = recordSaves(of: store)
		let copy = scratchpad("X∧Y")

		store.insertCopy(copy)

		#expect(store.scratchpads.count == 2)
		#expect(log.changed == [copy.id])
	}
}

/// The scratchpad value: its title, when it counts as empty, and the English kept beside the logic
struct LogicScratchpadTests {
	let letters = LogicLetters.defaults

	@Test func aNewScratchpadIsEmpty() {
		#expect(LogicScratchpad().isEmpty)
	}

	@Test func logicMakesItNotEmpty() {
		var pad = LogicScratchpad()
		pad.logic = Logic.entries("X")

		#expect(!pad.isEmpty)
	}

	@Test func englishMakesItNotEmpty() {
		var pad = LogicScratchpad()
		pad.english = "It rains."

		#expect(!pad.isEmpty)
	}

	@Test func spacesAloneAreEmpty() {
		var pad = LogicScratchpad()
		pad.english = "  \n"

		#expect(pad.isEmpty)
	}

	@Test func theTitleIsTheNameThenTheEnglishThenTheLogicThenUntitled() {
		var pad = LogicScratchpad()
		#expect(pad.title(letters: letters) == "Untitled")

		pad.logic = Logic.entries("X→Y")
		#expect(pad.title(letters: letters) == "X→Y")

		pad.english = "If X, then Y.\nMore."
		#expect(pad.title(letters: letters) == "If X, then Y.")

		pad.name = "Modus ponens"
		#expect(pad.title(letters: letters) == "Modus ponens")
	}

	@Test func theLogicLineStopsAtTheFirstNewLine() {
		var pad = LogicScratchpad()
		pad.logic = Logic.entries("X→Y\nX∴Y")

		#expect(pad.logicLine(letters: letters) == "X→Y")
	}

	@Test func theLogicLineUsesTheLettersGiven() {
		var pad = LogicScratchpad()
		pad.logic = Logic.entries("X→Y")

		#expect(pad.logicLine(letters: ["A", "B", "C", "D", "E", "F"]) == "A→B")
	}

	/// The Logic tab keeps `english` as the reading of `logic` while you type. This is that reading.
	@Test func theEnglishIsTheExactReadingOfTheLogic() {
		let weather = ["it rains", "the ground is wet", "", "", "", ""]

		let reading = Logic.reading("X→Y,X∴Y", descriptors: weather)

		#expect(reading == "If it rains, then the ground is wet.\nIt rains.\nTherefore, the ground is wet.")
	}

	@Test func logicThatDoesntParseHasNoReadingSoTheLastOneStays() {
		#expect(Logic.reading("X→") == nil)
	}

	@Test func aScratchpadSurvivesBeingEncoded() throws {
		let pad = scratchpad("X→Y,X∴Y")

		let data = try JSONEncoder().encode(pad)

		#expect(try JSONDecoder().decode(LogicScratchpad.self, from: data) == pad)
	}
}
