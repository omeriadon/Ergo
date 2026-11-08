//
//  ItemOfTheDayStore.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoCatalog
import Foundation

/// Today's item of the day, for the app and its widgets. The order comes from `ItemOfTheDay` and the library bundled
/// in the app, so there is nothing to download or keep: all this adds is the person's filter.
enum ItemOfTheDayStore {
	/// The filter as a set. Empty means every category.
	static var categories: Set<String> {
		Set(Defaults[.itemOfTheDayCategories])
	}

	/// Always sorted, and only categories the item of the day has, so a choice syncs as one value
	static func setCategories(_ categories: Set<String>) {
		let valid = categories.intersection(ItemOfTheDay.categories)
		Defaults[.itemOfTheDayCategories] = valid.count == ItemOfTheDay.categories.count ? [] : valid.sorted()
	}

	/// `category/id`, matching `LibraryCatalog.entryIDs`
	static func entryID(on date: Date = .now) -> String? {
		ItemOfTheDay.entry(on: date, categories: categories)
	}

	/// The entry for `entryID`, if the app's catalog resolves it. The catalog's ids are bare, without the category.
	static func reference(on date: Date = .now, catalog: CatalogIndex) -> CatalogReference? {
		entryID(on: date)
			.flatMap { $0.split(separator: "/", maxSplits: 1).last }
			.flatMap { catalog.resolve(String($0)) }
	}
}
