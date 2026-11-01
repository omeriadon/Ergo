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
						Button {} label: {
							CardView(title: "Biases", color: .red)
						}
						.buttonStyle(.plain)

						Button {} label: {
							CardView(title: "Concepts", color: .green)
						}
						.buttonStyle(.plain)
					}

					GridRow {
						Button {} label: {
							CardView(title: "Fallacies", color: .blue)
						}
						.buttonStyle(.plain)

						Button {} label: {
							CardView(title: "Symbols", color: .brown)
						}
						.buttonStyle(.plain)
					}

					GridRow {
						Button {} label: {
							CardView(title: "Paradoxes", color: .mint)
						}
						.buttonStyle(.plain)

						Button {} label: {
							CardView(title: "Philosophers", color: .indigo)
						}
						.buttonStyle(.plain)
					}

					GridRow {
						Button {} label: {
							CardView(title: "Razors", color: .yellow)
						}
						.buttonStyle(.plain)
					}
				}
				.padding()
			}
		}
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
