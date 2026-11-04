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
					.onscreenEntity(BiasEntity.self, id: id)

			case .concepts:
				ConceptDetailView(id: id)
					.onscreenEntity(ConceptEntity.self, id: id)

			case .fallacies:
				FallacyDetailView(id: id)
					.onscreenEntity(FallacyEntity.self, id: id)

			case .symbols:
				SymbolDetailView(id: id)
					.onscreenEntity(SymbolEntity.self, id: id)

			case .paradoxes:
				ParadoxDetailView(id: id)
					.onscreenEntity(ParadoxEntity.self, id: id)

			case .philosophers:
				PhilosopherDetailView(id: id)
					.onscreenEntity(PhilosopherEntity.self, id: id)

			case .razors:
				RazorDetailView(id: id)
					.onscreenEntity(RazorEntity.self, id: id)

			case .arguments:
				ArgumentDetailView(id: id)
					.onscreenEntity(ArgumentEntity.self, id: id)
		}
	}
}
