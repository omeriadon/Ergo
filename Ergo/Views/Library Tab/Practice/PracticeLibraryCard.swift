//
//  PracticeLibraryCard.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import Defaults
import ErgoCatalog
import SwiftUI

/// Practice on the Library tab's grid, with how many cards are due
struct PracticeLibraryCard: View {
	@Default(.practiceProgress) private var progress

	var body: some View {
		let due = progress.dueCount(at: .now)

		CardView(title: "Practice", color: .indigo)
			.overlay(alignment: .trailing) {
				if due > 0 {
					Text("\(due) due")
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
						.padding(.trailing, 40)
				}
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier("library.practice")
	}
}

/// Practice in the wide layout's sidebar, badged with how many cards are due
struct PracticeSidebarRow: View {
	@Default(.practiceProgress) private var progress

	var body: some View {
		Label("Practice", systemImage: PracticeView.symbol)
			.badge(progress.dueCount(at: .now))
	}
}
