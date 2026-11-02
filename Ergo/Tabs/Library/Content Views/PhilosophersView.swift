//
//  PhilosophersView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import FuzzyMatch
import SwiftUI

struct PhilosophersView: View {
	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var searchTerm = ""

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
		searchPhilosophers(
			catalog.philosophers.philosophers,
			query: searchPresented ? searchTerm : ""
		)
	}

	private var groupedPhilosophers: [(century: Int, philosophers: [Philosopher])] {
		let groups = Dictionary(grouping: catalog.philosophers.philosophers) {
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
						HStack {
							Text(philosopher.name)
							Spacer()
						}
					}
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
	}

	func searchPhilosophers(
		_ philosophers: [Philosopher],
		query: String
	) -> [Philosopher] {
		guard !query.isEmpty else { return philosophers }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()

		return philosophers.compactMap { philosopher -> (Philosopher, Double)? in
			let fields: [(String, Double)] = [
				(philosopher.name, 1.0),
				(philosopher.summary, 0.5),
			]

			let score = fields.compactMap { text, weight in
				matcher.score(
					text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * weight }
			}.max()

			guard let score else { return nil }
			return (philosopher, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}
}
