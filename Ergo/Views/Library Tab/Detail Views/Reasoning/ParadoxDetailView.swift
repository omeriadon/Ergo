//
//  ParadoxDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import SwiftUI

struct ParadoxDetailView: View {
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
					LibraryContent.paradoxes.themeColor.toSIMD3,
					LibraryContent.paradoxes.themeColor.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let paradox = catalog.paradoxes.paradoxes.first(where: { $0.id == id }) {
				// Derive indices dynamically so they shift cleanly if something is missing
				let hasOrigin = paradox.origin?.isEmpty == false

				let originIndex = 4
				let examplesIndex = originIndex + (hasOrigin ? 1 : 0)
				let misreadingsIndex = examplesIndex + 1
				let criticismsIndex = misreadingsIndex + 1
				let lookalikesIndex = criticismsIndex + 1
				let relatedIndex = lookalikesIndex + 1
				let tagsIndex = relatedIndex + 1

				ScrollView {
					LazyVStack(alignment: .leading) {
						AliasTitle(name: paradox.name, aliases: paradox.aliases)

						Spacer()
							.frame(height: 10)

						Text(paradox.summary)
							.textSelection(.enabled)
							.lineLimit(10)
							.bounceOnAppear(after: 1)

						RelatedSection(list: paradox.keyFigures, title: "Key Figures")
							.padding(.top)
							.bounceOnAppear(after: 2)

						Spacer()
							.frame(height: 20)

						Text(paradox.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.bounceOnAppear(after: 3)

						if let origin = paradox.origin, !origin.isEmpty {
							NotesSection(list: [origin], title: "Origin")
								.padding(.top)
								.bounceOnAppear(after: originIndex)
						}

						ExamplesSection(list: paradox.examples)
							.padding(.top)
							.bounceOnAppear(after: examplesIndex)

						NotesSection(list: paradox.commonMisreadings, title: "Common Misreadings")
							.padding(.top)
							.bounceOnAppear(after: misreadingsIndex)

						NotesSection(list: paradox.criticisms, title: "Criticisms")
							.padding(.top)
							.bounceOnAppear(after: criticismsIndex)

						LookalikeSection(list: paradox.lookalikes)
							.padding(.top)
							.bounceOnAppear(after: lookalikesIndex)

						RelatedSection(list: paradox.related)
							.padding(.top)
							.bounceOnAppear(after: relatedIndex)

						TagSection(list: paradox.tags.map { tag in
							CatalogTag(
								id: "paradoxes.\(tag.rawValue)",
								title: tag.title,
								route: .paradoxes(filter: tag)
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
				.navigationTitle(paradox.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(paradox.name, category: "Paradoxes", hasScrolled: hasScrolled)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					LibraryDetailMenu(reference: CatalogReference(
						id: paradox.id,
						name: paradox.name,
						category: .paradoxes
					))
				}

			} else {
				Text("Paradox not found")

				Button {
					navigation.libraryPath.removeLast()
				} label: {
					Text("Go Back")
				}
			}
		}
	}
}
