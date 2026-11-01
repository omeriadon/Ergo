//
//  LibraryDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct ItemDetailView: View {
	let route: ItemRoute
	let origin: ItemTab

	var body: some View {
		switch route {
			case .claim(_):
//				ClaimDetailView(id: id)
				Text("not yet")

			case .source(_):
//				SourceDetailView(id: id)
				Text("not yet")

			case .analysis(_):
//				AnalysisDetailView(id: id)
				Text("not yet")

			case .evidence(_):
//				EvidenceDetailView(id: id)
				Text("not yet")
		}
	}
}
