//
//  BeliefsLibraryCard.swift
//  Ergo
//
//  Created by Adon Omeri on 16/11/2026.
//

import Defaults
import ErgoCatalog
import SwiftUI

/// Beliefs on the Library tab's grid, with how many beliefs there are
struct BeliefsLibraryCard: View {
	@Default(.beliefs) private var ledger

	var body: some View {
		let count = ledger.listed.count

		CardView(title: "Beliefs", color: .teal)
			.overlay(alignment: .trailing) {
				if count > 0 {
					Text("^[\(count) belief](inflect: true)")
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
						.padding(.trailing, 40)
				}
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier("library.beliefs")
	}
}

/// Beliefs in the wide layout's sidebar
struct BeliefsSidebarRow: View {
	var body: some View {
		Label("Beliefs", systemImage: BeliefsView.symbol)
	}
}
