//
//  PhilosophersView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Defaults
import SwiftUI

struct PhilosophersView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	@State private var searchTerm = ""
	@State private var searchedPhilosophers: [Philosopher] = []

	@State private var searchPresented = false

	var main: some View {
		List {
			results

			if !searchPresented {
				Text("\(catalog.philosophers.philosophers.count) philosphers")
					.font(.caption)
					.foregroundStyle(.secondary)
					.listRowBackground(Color.clear)
			}
		}
		.animation(
			reduceMotion ? nil : .smooth(duration: 0.22),
			value: filteredPhilosphers.map(\.id)
		)
		.animation(.easeInOut(duration: 0.2), value: searchPresented)
		.listSectionIndexVisibility(.visible)
		.scrollEdgeEffectStyle(.soft, for: .all)
		.buttonStyle(.plain)
		.toolbarMinimizationBehavior(.never, for: .navigationBar)
		.searchable(
			text: $searchTerm,
			isPresented: $searchPresented,
			placement: .navigationBarDrawer(displayMode: .always),
			prompt: "Search philosphers"
		)
		.searchPresentationToolbarBehavior(.avoidHidingContent)
		.navigationTitle("Philosophers")
	}

	private var filteredPhilosphers: [Philosopher] {
		guard searchPresented, !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			return catalog.philosophers.philosophers
		}
		return Array(searchedPhilosophers.prefix(CatalogSearch.resultLimit))
	}

	private var groupedPhilosophers: [(century: Int, philosophers: [Philosopher])] {
		let groups = Dictionary(grouping: filteredPhilosphers) {
			Int(floor(Double($0.birthYear - 1) / 100)) + 1
		}

		return groups.keys.sorted().map { century in
			(
				century: century,
				philosophers: groups[century]!.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
			)
		}
	}

	var results: some View {
		ForEach(groupedPhilosophers, id: \.century) { group in
			Section("\(group.century)") {
				ForEach(group.philosophers) { philosopher in
					NavigationLink(
						value: LibraryRoute.detail(
							category: .philosophers,
							id: philosopher.id
						)
					) {
						let target = CatalogReference(id: philosopher.id, name: philosopher.name, category: .philosophers)

						let isBookmarked = bookmarks.contains(target)

						HStack {
							ZStack {
								PhilosopherThumbnail(id: philosopher.id)

								Color.white.opacity(0)
									.contentShape(Circle())
									.background {
										LiquidLens(
											isLifted: true,
											animated: true,
											configuration: .init(
												style: 1,
												warpsContentBelow: true,
												restingBackgroundColor: .white.withAlphaComponent(0),
												liftedDisplacement: 0
											),
											configure: { handle in
												guard let flex = handle.value(for: .flexInteraction) as? NSObject else {
													return
												}

												handle.setValue(
													0,
													forKeyPath: "preferredFlexSources",
													on: flex
												)
											}
										)
									}
							}
							.frame(width: 40, height: 40)

							Text(philosopher.name)

							Spacer()

							if isBookmarked {
								Image(systemName: "bookmark")
									.foregroundStyle(.secondary)
									.symbolVariant(.fill)
							}
						}
						.contextMenu {
							Button {
								withAnimation(.easeInOut) {
									if isBookmarked {
										bookmarks.remove(target)
									} else {
										bookmarks.insert(target)
									}
								}
							} label: {
								if isBookmarked {
									Label("Remove Bookmark", systemImage: "bookmark.fill")
								} else {
									Label("Bookmark", systemImage: "bookmark")
								}
							}
						} preview: {
							LibraryDetailView(category: target.category, id: target.id)
								.environment(catalog)
								.environment(navigation)
						}
					}
					.transition(.opacity)
				}
			}
			.sectionIndexLabel("\(group.century)")
		}
	}

	var body: some View {
		main
			.toolbar {
				ToolbarItem(placement: .title) {
					Text("Philosphers")
				}
			}
			.task(id: "\(searchPresented)-\(searchTerm.trimmingCharacters(in: .whitespacesAndNewlines))-\(catalog.isLoaded)") {
				let query = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
				guard searchPresented, !query.isEmpty, catalog.isLoaded else {
					searchedPhilosophers = []
					return
				}
				do {
					try await Task.sleep(for: .milliseconds(120))
					let matches = try await CatalogSearch.ranked(
						catalog.philosophers.philosophers,
						query: query,
						limit: CatalogSearch.resultLimit
					) { $0.searchFields }
					try Task.checkCancellation()
					searchedPhilosophers = matches
				} catch is CancellationError {
					return
				} catch {
					searchedPhilosophers = []
				}
			}
	}
}
