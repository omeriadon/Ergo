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
				BiasesView()

			case .concepts:
				ConceptsView()

			case .fallacies:
				FallaciesView()

			case .symbols:
				SymbolsView()

			case .paradoxes:
				ParadoxesView()

			case .philosophers:
				PhilosophersView()

			case .razors:
				RazorsView()
		}
	}
}
