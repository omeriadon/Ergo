//
//  LibraryFilterSuggestions.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

/// The filters that match what's being typed, which turn into tokens when tapped
struct LibraryFilterSuggestions<Item: LibraryListItem>: View {
	let suggestions: [LibraryFilter]
	let state: LibraryListState
	let donate: () -> Void

	var body: some View {
		Section("Filters") {
			ForEach(suggestions) { filter in
				Button {
					state.toggle(filter)
					state.searchText = ""
					donate()
				} label: {
					Label(filter.title, systemImage: filter.kind.tokenImage)
				}
				.accessibilityIdentifier("library.\(Item.category.rawValue).filter.\(filter.key)")
			}
		}
	}
}
