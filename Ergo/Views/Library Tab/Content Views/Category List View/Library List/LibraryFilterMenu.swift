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

	#if os(macOS)
		@State private var isShowingFilters = false
	#endif

	private var kinds: [LibraryFilter.Kind] {
		Set(Item.availableFilters.map(\.kind)).sorted()
	}

	var body: some View {
		#if os(macOS)
			popoverButton
		#else
			menu
		#endif
	}

	private var menu: some View {
		let kinds = kinds

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

	#if os(macOS)
		/// A Mac menu closes after every pick, so picking several filters is a popover of checkboxes instead
		private var popoverButton: some View {
			Button("Filters", systemImage: "line.3.horizontal.decrease") {
				isShowingFilters.toggle()
			}
			.labelStyle(.iconOnly)
			.accessibilityIdentifier("library.\(Item.category.rawValue).filters")
			.popover(isPresented: $isShowingFilters, arrowEdge: .bottom) {
				filterPopover
			}
		}

		private var filterPopover: some View {
			VStack(alignment: .leading, spacing: 12) {
				ForEach(kinds, id: \.self) { kind in
					VStack(alignment: .leading, spacing: 6) {
						if kinds.count > 1 {
							Label(kind.title, systemImage: kind.systemImage)
								.font(.headline)
						}
						filterToggles(of: kind)
							.toggleStyle(.checkbox)
					}
				}

				Divider()

				clearButton
			}
			.padding()
			.frame(minWidth: 220, alignment: .leading)
		}

		private var clearButton: some View {
			Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle") {
				withAnimation(.easeInOut(duration: 0.2)) {
					state.clearFilters()
				}
				IntentDonations.clearFilters()
			}
			.disabled(state.filters.isEmpty)
			.accessibilityIdentifier("library.\(Item.category.rawValue).clearFilters")
		}
	#endif

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
