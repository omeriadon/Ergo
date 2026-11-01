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
					.font(.title2)
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
					VStack(spacing: 20) {
						Image("Ergo")
							.resizable()
							.aspectRatio(contentMode: .fit)
							.foregroundStyle(.accent.gradient)
							.frame(width: 50, height: 50)
						Text("Search Something")
							.font(.title3)
					}
					.padding(.top, 90)
					.listRowBackground(Color.clear)
					.frame(maxWidth: .infinity, alignment: .center)
					.transition(.opacity)
				} else {
					//					results here
					//									.transition(.opacity)
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

						NavigationLink(value: LibraryRoute.category(.symbols)) {
							CardView(title: "Symbols", color: .brown)
						}
					}

					GridRow {
						NavigationLink(value: LibraryRoute.category(.paradoxes)) {
							CardView(title: "Paradoxes", color: .mint)
						}

						NavigationLink(value: LibraryRoute.category(.philosophers)) {
							CardView(title: "Philosophers", color: .purple)
						}
					}

					GridRow {
						NavigationLink(value: LibraryRoute.category(.razors)) {
							CardView(title: "Razors", color: .yellow)
						}
					}
				}
				.padding()
				.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.1), value: "\(searchPresented)\(searchTerm.isEmpty)")
		.buttonStyle(.plain)
		.searchable(
			text: $searchTerm,
			isPresented: $searchPresented,
			placement: .toolbarPrincipal,
			prompt: "Search anything"
		)
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle("Library")
		.toolbar {
			ToolbarItem(placement: .title) {
				Text("Library")
					.fontDesign(.rounded)
					.font(.title)
			}
		}
	}
}
