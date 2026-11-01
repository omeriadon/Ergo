//
//  LibraryTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

private struct CardView: View {
	let title: String
	let color: Color

	var body: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading) {
				Text(title)
					.font(.title3)
					.padding(.bottom)
			}

			Spacer()

			Image(systemName: "chevron.right")
				.padding(.trailing, 3)
		}
		.padding(11)
		.glassEffect(.clear.tint(color).interactive(), in: RoundedRectangle(cornerRadius: 18))
	}
}

struct LibraryTabView: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(CatalogStore.self) private var catalog

	@State private var searchTerm = ""

	@State private var searchPresented = false

	var body: some View {
		ScrollView {
			if searchPresented {
				if searchTerm.isEmpty {
					ContentUnavailableView("Search Something", image: "Ergo")
				}

			} else {
				Grid(horizontalSpacing: 12, verticalSpacing: 12) {
					GridRow {
						NavigationLink(value: LibraryRoute.category(.biases)) {
							CardView(title: "Biases", color: .red)
						}

						NavigationLink(value: LibraryRoute.category(.concepts)) {
							CardView(title: "Concepts", color: .green)
						}
					}

					GridRow {
						NavigationLink(value: LibraryRoute.category(.fallacies)) {
							CardView(title: "Fallacies", color: .blue)
						}

						NavigationLink(value: LibraryRoute.category(.concepts)) {
							CardView(title: "Symbols", color: .brown)
						}
					}

					GridRow {
						NavigationLink(value: LibraryRoute.category(.concepts)) {
							CardView(title: "Paradoxes", color: .mint)
						}

						NavigationLink(value: LibraryRoute.category(.concepts)) {
							CardView(title: "Philosophers", color: .purple)
						}
					}

					GridRow {
						NavigationLink(value: LibraryRoute.category(.concepts)) {
							CardView(title: "Razors", color: .yellow)
						}
					}
				}
				.padding()
			}
		}
		.buttonStyle(.plain)
		.searchable(
			text: $searchTerm,
			isPresented: $searchPresented,
			placement: .toolbarPrincipal,
			prompt: "Search anything"
		)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .title) {
				Text("Library")
					.fontDesign(.rounded)
					.font(.title)
			}
		}
	}
}
