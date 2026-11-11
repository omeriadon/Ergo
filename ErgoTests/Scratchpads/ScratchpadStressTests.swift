//
//  ScratchpadStressTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 11/11/2026.
//

import Defaults
@testable import Ergo
import ErgoLogic
import ErgoSync
import Foundation
import Testing

/// Scratchpads made, typed in, emptied, renamed and deleted in an order nobody would choose. Each test takes a seed,
/// so one that fails does so every time.
@Suite(.cleanDefaults)
struct ScratchpadStressTests {
	static let keys: [LogicKeyboardEntry] = (1 ... 6).map(LogicKeyboardEntry.variable)
		+ ["¬", "∧", "∨", "⊕", "→", "↔", "□", "◇", "∀", "∃", "=", "∈", "≔", "∴"].map(LogicKeyboardEntry.symbol)
		+ ["(", ")", "\n", ","].map(LogicKeyboardEntry.delimiter)

	/// Logic as a cat on the keyboard would write it: most of it doesn't parse
	static func logic(_ random: inout SeededRandom) -> [LogicKeyboardEntry] {
		(0 ..< Int.random(in: 0 ... 40, using: &random)).map { _ in keys.randomElement(using: &random)! }
	}

	static func typed(_ random: inout SeededRandom, into scratchpad: LogicScratchpad) -> LogicScratchpad {
		var scratchpad = scratchpad
		scratchpad.logic = random.chance(5) ? [] : logic(&random)
		scratchpad.english = LogicEnglish.text(for: LogicParser.parse(scratchpad.logic), letters: LogicLetters.defaults, descriptors: scratchpad.descriptors) ?? ""
		return scratchpad
	}

	@Test(arguments: 0 ..< 60 as Range<UInt64>)
	func syncHearsOfExactlyTheScratchpadsThatAreKept(seed: UInt64) throws {
		var random = SeededRandom(seed: seed)
		let store = ScratchpadStore.test()
		var known: Set<UUID> = []
		store.didSave = { changed, deleted in
			known.formUnion(changed.map(\.id))
			known.subtract(deleted)
		}

		for _ in 0 ..< 150 {
			let some = random.chance(6) ? UUID() : store.scratchpads.randomElement(using: &random)?.id ?? UUID()
			switch Int.random(in: 0 ..< 9, using: &random) {
				case 0, 1, 2, 3:
					store.current = Self.typed(&random, into: store.current)
				case 4:
					store.newScratchpad()
				case 5:
					store.open(some)
				case 6:
					store.delete([some])
				case 7:
					try store.rename(some, to: #require(["", "  ", "Weather", "👨‍👩‍👧"].randomElement(using: &random)))
				default:
					store.discardCurrentIfEmpty()
			}

			let ids = store.scratchpads.map(\.id)
			#expect(Set(ids).count == ids.count, "Expected every scratchpad once")
			#expect(store.sortedScratchpads.count == ids.count)
		}
		store.save()

		#expect(known == Set(store.scratchpads.map(\.id)))
		#expect(Defaults[.scratchpads] == store.scratchpads)
	}

	@Test(arguments: 100 ..< 160 as Range<UInt64>)
	func anyScratchpadComesBackFromItsRecord(seed: UInt64) throws {
		var random = SeededRandom(seed: seed)
		var scratchpad = Self.typed(&random, into: LogicScratchpad())
		scratchpad.name = try #require(["", "Weather", "👨‍👩‍👧", String(repeating: "long ", count: 100)].randomElement(using: &random))
		for slot in scratchpad.descriptors.indices where random.chance(2) {
			scratchpad.descriptors[slot] = try #require(["it rained", "the ground is wet", "é", ""].randomElement(using: &random))
		}
		var replica = SyncReplica.caughtUp(device: "other")
		try replica.recordLocal(kind: .scratchpad, id: ScratchpadRecord.id(scratchpad.id), fields: ScratchpadRecord.fields(of: scratchpad))

		let rebuilt = ScratchpadRecord.rebuild([scratchpad.id], from: replica, local: [])

		let back = try #require(rebuilt.scratchpads.first)
		#expect(rebuilt.deleted.isEmpty)
		#expect(back.id == scratchpad.id)
		#expect(back.name == scratchpad.name)
		#expect(back.descriptors == scratchpad.descriptors)
		#expect(back.logic == scratchpad.logic)
		#expect(back.english == scratchpad.english)
	}
}
