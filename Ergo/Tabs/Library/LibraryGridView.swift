//
//  LibraryGridView.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import SwiftUI

struct LibraryGridView: View {
	var body: some View {
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
					CardView(title: "Symbols", color: .orange)
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
				NavigationLink(value: LibraryRoute.category(.arguments)) {
					CardView(title: "Arguments", color: .teal)
				}
			}

			Spacer()
				.frame(height: 30)

			GridRow {
				NavigationLink(value: LibraryRoute.bookmarks) {
					CardView(title: "Bookmarks", color: .accent)
				}
				.gridCellColumns(2)
			}
		}
	}
}
