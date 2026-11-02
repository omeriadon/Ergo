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
}
