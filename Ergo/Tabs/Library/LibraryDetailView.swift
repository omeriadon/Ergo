//
//  LibraryDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct LibraryDetailView: View {
	let category: LibraryContent
	let id: String

	var body: some View {
		switch category {
			case .biases:
				BiasDetailView(id: id)

			case .concepts:
				ConceptDetailView(id: id)

			case .fallacies:
				FallacyDetailView(id: id)

			case .symbols:
				SymbolDetailView(id: id)

			case .paradoxes:
				ParadoxDetailView(id: id)

			case .philosophers:
				PhilosopherDetailView(id: id)

			case .razors:
				RazorDetailView(id: id)

			case .arguments:
				ArgumentDetailView(id: id)
		}
	}
}
