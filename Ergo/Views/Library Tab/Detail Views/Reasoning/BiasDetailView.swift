//
//  BiasDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct BiasDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var hasScrolled = false
	@State private var isOpening = true

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var conf = detailViewConf
				conf.palette = [
					LibraryContent.biases.themeColor.toSIMD3,
					LibraryContent.biases.themeColor.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let bias = catalog.biases.biases.first(where: { $0.id == id }) {
				// Derive indices dynamically so they shift cleanly if something is missing
				let hasEvidenceNote = bias.evidenceNote?.isEmpty == false
				let hasCounters = !bias.counters.isEmpty

				let evidenceNoteIndex = 3
				let countersIndex = evidenceNoteIndex + (hasEvidenceNote ? 1 : 0)
				let examplesIndex = countersIndex + (hasCounters ? 1 : 0)
				let limitationsIndex = examplesIndex + 1
				let lookalikesIndex = limitationsIndex + 1
				let relatedIndex = lookalikesIndex + 1
				let tagsIndex = relatedIndex + 1

				ScrollView {
					LazyVStack(alignment: .leading) {
						AliasTitle(name: bias.name, aliases: bias.aliases)

						Spacer()
							.frame(height: 10)

						Text(bias.summary)
							.textSelection(.enabled)
							.lineLimit(10)
							.bounceOnAppear(after: 1)

						Text(bias.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
							.bounceOnAppear(after: 2)

						if let evidenceNote = bias.evidenceNote, !evidenceNote.isEmpty {
							NotesSection(list: [evidenceNote], title: "Evidence Note")
								.padding(.top)
								.bounceOnAppear(after: evidenceNoteIndex)
						}

						if !bias.counters.isEmpty {
							VStack(alignment: .leading, spacing: 13) {
								Text("Counters")
									.textCase(.uppercase)
									.foregroundStyle(.accent)

								VStack(alignment: .leading, spacing: 4) {
									ForEach(bias.counters, id: \.self) { counter in
										Text("-  \(counter)")
									}
								}
							}
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
							.bounceOnAppear(after: countersIndex)
						}

						ExamplesSection(list: bias.examples)
							.padding(.top)
							.bounceOnAppear(after: examplesIndex)

						NotesSection(list: bias.limitations)
							.padding(.top)
							.bounceOnAppear(after: limitationsIndex)

						LookalikeSection(list: bias.lookalikes)
							.padding(.top)
							.bounceOnAppear(after: lookalikesIndex)

						RelatedSection(list: bias.related)
							.padding(.top)
							.bounceOnAppear(after: relatedIndex)

						TagSection(list: bias.tags.map { tag in
							CatalogTag(
								id: "biases.\(tag.rawValue)",
								title: tag.title,
								route: .biases(filter: tag)
							)
						})
						.padding(.top)
						.bounceOnAppear(after: tagsIndex)

						Spacer()
							.frame(height: 40)
					}
					.padding(.horizontal)
					.frame(maxWidth: .infinity, alignment: .leading)
					.environment(\.isOpeningDetail, isOpening)
				}
				.task {
					try? await Task.sleep(for: .milliseconds(200))
					isOpening = false
				}
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(bias.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(bias.name, category: "Biases", hasScrolled: hasScrolled)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					LibraryDetailMenu(reference: CatalogReference(
						id: bias.id,
						name: bias.name,
						category: .biases
					))
				}

			} else {
				Text("Bias not found")

				Button {
					navigation.libraryPath.removeLast()
				} label: {
					Text("Go Back")
				}
			}
		}
	}
}
