//
//  LibraryFilterMenu.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

/// The toolbar's filter menu: toggles for each kind of filter, and a way to clear them
struct LibraryFilterMenu<Item: LibraryListItem>: View {
	let state: LibraryListState
	let donate: () -> Void

	var body: some View {
		let kinds = Set(Item.availableFilters.map(\.kind)).sorted()

		return Menu {
			if kinds.count > 1 {
				ForEach(kinds, id: \.self) { kind in
					Menu(kind.title, systemImage: kind.systemImage) {
						filterToggles(of: kind)
					}
					.menuActionDismissBehavior(.disabled)
				}
			} else if let kind = kinds.first {
				filterToggles(of: kind)
			}

			Divider()

			Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle") {
				withAnimation(.easeInOut(duration: 0.2)) {
					state.clearFilters()
				}
				IntentDonations.clearFilters()
			}
			.disabled(state.filters.isEmpty)
			.accessibilityIdentifier("library.\(Item.category.rawValue).clearFilters")
		} label: {
			Label("Filters", systemImage: "line.3.horizontal.decrease")
				.labelStyle(.iconOnly)
		}
		.accessibilityIdentifier("library.\(Item.category.rawValue).filters")
		.menuActionDismissBehavior(.disabled)
	}

	private func filterToggles(of kind: LibraryFilter.Kind) -> some View {
		ForEach(Item.availableFilters.filter { $0.kind == kind }) { filter in
			Toggle(
				filter.title,
				isOn: Binding(
					get: {
						state.filters.contains(filter)
					},
					set: { _ in
						withAnimation(.easeInOut(duration: 0.2)) {
							state.toggle(filter)
						}
						donate()
					}
				)
			)
		}
	}
}
