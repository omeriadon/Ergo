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
					case "Bookmarks":
						"bookmark"
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
		.glassEffect(.clear.tint(color).interactive(), in: RoundedRectangle(cornerRadius: 22))
	}
}

struct LibraryTabView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(CatalogStore.self) private var catalog

	@State private var searchTerm = ""

	@State private var searchPresented = false
	@State private var searchResults: [LibrarySearchEntry] = []

	private var libraryEntries: [LibrarySearchEntry] {
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
		return entries
	}

	var body: some View {
		let results = searchPresented ? searchResults : []

		ScrollView {
			if searchPresented {
				if searchTerm.isEmpty {
					VStack(spacing: 20) {
						Image("Ergo")
							.resizable()
							.aspectRatio(contentMode: .fit)
							.foregroundStyle(.accent.gradient)
							.frame(width: 50, height: 50)
						Text("Search anything")
							.font(.title3)
					}
					.padding(.top, 90)
					.listRowBackground(Color.clear)
					.frame(maxWidth: .infinity, alignment: .center)
					.transition(.opacity)
				} else if results.isEmpty, searchTerm.count > 2 {
					ContentUnavailableView.search(text: searchTerm)
						.tint(.accent)
						.padding(.top, 90)
						.transition(.opacity)
				} else {
					LazyVStack(alignment: .leading, spacing: 10) {
						ForEach(results) { result in
							NavigationLink(
								value: LibraryRoute.detail(category: result.category, id: result.id)
							) {
								HStack {
									Label {
										Text(result.name)
									} icon: {
										Image(systemName: result.category.symbol)
											.foregroundStyle(.accent)
									}
									.font(.title3)
									.frame(maxWidth: .infinity, alignment: .leading)
									.labelIconToTitleSpacing(10)

									Spacer()

									Image(systemName: "chevron.right")
										.foregroundStyle(.accent.secondary)
								}
							}
							.accessibilityIdentifier("library.search.\(result.category).\(result.id)")
							.padding(.horizontal, 16)
							.padding(.vertical, 16)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
							.contentShape(RoundedRectangle(cornerRadius: 18))
							.transition(.opacity)
						}
					}
					.padding(.horizontal, 7)
					.padding(.top, 20)
					.transition(.opacity)
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

					Spacer()
						.frame(height: 30)

					GridRow {
						NavigationLink(value: LibraryRoute.bookmarks) {
							CardView(title: "Bookmarks", color: .accent)
						}
						.gridCellColumns(2)
					}
				}
				.padding()
				.transition(.opacity)
			}
		}
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: results.map(\.id)
		)
		.animation(.easeInOut(duration: 0.1), value: "\(searchPresented)\(searchTerm.isEmpty)")
		.buttonStyle(.plain)
		.searchable(
			text: $searchTerm,
			isPresented: $searchPresented,
			placement: .toolbarPrincipal,
			prompt: "Search anything"
		)
		.scrollEdgeEffectStyle(.soft, for: .all)
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle("Library")
		.toolbar {
			ToolbarItem(placement: .title) {
				Text("Library")
					.fontDesign(.rounded)
					.font(.title)
			}
		}
		.task(id: "\(searchPresented)-\(searchTerm.trimmingCharacters(in: .whitespacesAndNewlines))-\(catalog.isLoaded)") {
			let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
			guard searchPresented, !query.isEmpty, catalog.isLoaded else {
				searchResults = []
				return
			}
			do {
				try await Task.sleep(for: .milliseconds(120))
				let entries = libraryEntries
				let matches = try await CatalogSearch.ranked(
					entries,
					query: query,
					limit: CatalogSearch.resultLimit
				) { $0.searchFields }
				try Task.checkCancellation()
				searchResults = matches
			} catch is CancellationError {
				return
			} catch {
				searchResults = []
			}
		}
	}
}
