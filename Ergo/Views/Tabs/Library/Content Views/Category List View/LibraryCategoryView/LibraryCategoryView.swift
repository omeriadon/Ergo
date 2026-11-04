//
//  LibraryCategoryView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct LibraryCategoryView: View {
	let category: LibraryContent

	var body: some View {
		switch category {
			case .biases:
				LibraryListView<Bias>()

			case .concepts:
				LibraryListView<Concept>()

			case .fallacies:
				LibraryListView<Fallacy>()

			case .symbols:
				LibraryListView<LogicSymbol>()

			case .paradoxes:
				LibraryListView<Paradox>()

			case .philosophers:
				LibraryListView<Philosopher>()

			case .razors:
				LibraryListView<Razor>()

			case .arguments:
				LibraryListView<Argument>()
		}
	}
}
