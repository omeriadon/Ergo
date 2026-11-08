//
//  PendingBreakDown.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoProtocol
import Foundation

/// A breakdown the server is working on, or has finished and is waiting for the person to create from. It carries on if
/// the app is closed, so this is kept (`Defaults[.pendingBreakDown]`) to find it again: sending `request` once more hears
/// the same run from the start. It goes when the breakdown is created, cancelled, edited or fails.
nonisolated struct PendingBreakDown: Codable, Hashable, Sendable, Defaults.Serializable {
	var request: TranslateRequest

	/// What the new board's source is. Nil when it's the text itself.
	var input: BoardSource.Content?

	/// The source on the current board that this is a breakdown of
	var existing: BoardSource.ID?

	/// Whether a sheet showing this input is the one this belongs to. A page shared again is read again and may differ in a
	/// few words, so what it came from decides when there is one, and the text only when there isn't.
	func matches(english: String, input: BoardSource.Content?, existing: BoardSource.ID?) -> Bool {
		guard input == self.input, existing == self.existing else { return false }
		return input != nil || existing != nil || english.trimmingCharacters(in: .whitespacesAndNewlines) == request.english
	}
}
