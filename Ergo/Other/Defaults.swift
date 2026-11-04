//
//  Defaults.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import Foundation

extension Defaults.Keys {
	static let bookmarks = Key<Set<CatalogReference>>(
		"bookmarks",
		default: []
	)

	static let selectedTab = Key<AppTab>("selectedTab", default: .check)

	static let libraryPath = Key<[LibraryRoute]>("libraryPath", default: [])
	static let debatePath = Key<[DebateRoute]>("debatePath", default: [])

	static let presentedSheet = Key<AppSheet?>("presentedSheet", default: nil)

	static let librarySearchText = Key<[LibraryContent: String]>("librarySearchText", default: [:])

	static let libraryGeneralSearchText = Key<String>("libraryGeneralSearchText", default: "")

	static let logicLetters = Key<[String]>("logicLetters", default: ["X", "Y", "Z", "P", "Q", "R"])

	static let lastIndexedVersion = Key<String>(
		"lastIndexedVersion",
		default: ""
	)
}
