//
//  LibraryListState.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import Foundation
import Observation

@Observable
final class LibraryListState {
	var searchText = ""

	var filters: [LibraryFilter] = []

	func toggle(_ filter: LibraryFilter) {
		if let index = filters.firstIndex(of: filter) {
			filters.remove(at: index)
		} else {
			filters.append(filter)
		}
	}

	func add(_ filter: LibraryFilter) {
		if !filters.contains(filter) {
			filters.append(filter)
		}
	}

	func clearFilters() {
		filters = []
	}
}
