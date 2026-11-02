//
//  LibraryTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import FuzzyMatch
import SwiftUI

private struct CardView: View {
	let title: String
	let color: Color

	var body: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 8) {
				let image = switch title {
					case "Biases":
						"distribute.vertical.center"
					case "Razors":
						"scissors"
					case "Symbols":
						"f.cursive"
					case "Concepts":
						"book.closed"
					case "Paradoxes":
						"infinity"
					case "Philosophers":
						"brain.head.profile"
					case "Fallacies":
						"repeat.badge.xmark"
					case "Arguments":
						"text.bubble"
					default:
						""
				}

				Image(systemName: image)

				Text(title)
					.font(.title2)
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

	private var searchResults: [LibrarySearchEntry] {
		let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return [] }
		let biasResults = catalog.biases.biases.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .biases,
				searchFields: entry.searchFields
			)
		}
		let conceptResults = catalog.concepts.concepts.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .concepts,
				searchFields: entry.searchFields
			)
		}
		let fallacyResults = catalog.fallacies.fallacies.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .fallacies,
				searchFields: entry.searchFields
			)
		}
		let symbolResults = catalog.logicSymbols.symbols.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .symbols,
				searchFields: entry.searchFields
			)
		}
		let paradoxResults = catalog.paradoxes.paradoxes.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .paradoxes,
				searchFields: entry.searchFields
			)
		}
		let philosopherResults = catalog.philosophers.philosophers.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .philosophers,
				searchFields: entry.searchFields
			)
		}
		let razorResults = catalog.razors.razors.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .razors,
				searchFields: entry.searchFields
			)
		}
		let argumentResults = catalog.arguments.arguments.map { entry in
			LibrarySearchEntry(
				id: entry.id,
				name: entry.name,
				category: .arguments,
				searchFields: entry.searchFields
			)
		}
		var entries = biasResults
		entries += conceptResults
		entries += fallacyResults
		entries += symbolResults
		entries += paradoxResults
		entries += philosopherResults
		entries += razorResults
		entries += argumentResults
		return searchLibrary(entries, query: query)
	}

	func searchLibrary(
		_ entries: [LibrarySearchEntry],
		query: String
	) -> [LibrarySearchEntry] {
		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return [] }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()
		return entries.compactMap { entry -> (LibrarySearchEntry, Double)? in
			let score = entry.searchFields.compactMap { field in
				matcher.score(
					field.text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * field.weight }
			}.max()
			guard let score else { return nil }
			return (entry, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}

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
				} else if searchResults.isEmpty {
					ContentUnavailableView.search(text: searchTerm)
				} else {
					LazyVStack(alignment: .leading, spacing: 10) {
						ForEach(searchResults) { result in
							NavigationLink(
								value: LibraryRoute.detail(category: result.category, id: result.id)
							) {
								Label(result.name, systemImage: result.category.symbol)
							}
							.accessibilityIdentifier("library.search.\(result.category).\(result.id)")
							.padding(.horizontal)
							.padding(.vertical, 10)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
						}
					}
					.animation(.easeInOut(duration: 0.2), value: searchPresented)
					.animation(.easeInOut(duration: 0.2), value: searchTerm)
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
