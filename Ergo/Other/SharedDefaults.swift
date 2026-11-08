//
//  SharedDefaults.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import Foundation

// Keys the widgets read too, so they're stored in the App Group instead of the app's own defaults, which a widget can't
// see. Keep this file free of the app's types, since the widget target compiles it too (add it to that target's
// membership). Every key here still needs a sync decision, as in `Defaults.swift`.

extension Defaults.Keys {
	/// Synced. Which categories the item of the day (and its widgets) draws from. Empty means all. Kept sorted, so the
	/// same choice always encodes the same and doesn't sync as an edit.
	static let itemOfTheDayCategories = Key<[String]>(
		"itemOfTheDayCategories",
		default: [],
		suite: UserDefaults(suiteName: "group.com.adonis.Ergo") ?? .standard
	)
}
