import SwiftUI

struct ConceptDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog
	@Environment(NavigationManager.self) private var navigation

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var configuration = detailViewConf
				configuration.palette = [Color.green.toSIMD3, Color.green.toSIMD3]
				return configuration
			}())
				.ignoresSafeArea()

			if let concept = catalog.concepts.concepts.first(where: { $0.id == id }) {
				ScrollView {
					VStack(alignment: .leading) {
						AliasTitle(name: concept.name, aliases: concept.aliases)

						Spacer()
							.frame(height: 10)

						Text(concept.summary)
							.lineLimit(10)

						Text(concept.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)

						if let origin = concept.origin, !origin.isEmpty {
							NotesSection(list: [origin], title: "Origin")
								.padding(.top)
						}

						RelatedSection(list: concept.keyFigures, title: "Key Figures")
							.padding(.top)

						ExamplesSection(list: concept.examples)
							.padding(.top)

						NotesSection(list: concept.commonMisreadings, title: "Common Misreadings")
							.padding(.top)

						NotesSection(list: concept.criticisms, title: "Criticisms")
							.padding(.top)

						LookalikeSection(list: concept.lookalikes)
							.padding(.top)

						RelatedSection(list: concept.related)
							.padding(.top)

						let tags = concept.tags.map { tag in
							CatalogTag(
								id: "concepts.\(tag.rawValue)",
								title: tag.title,
								route: .concepts(filter: tag)
							)
						}
						TagSection(list: tags)
							.padding(.top)

						Spacer()
							.frame(height: 40)
					}
					.padding(.horizontal)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(concept.name.capitalized)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					ToolbarItem(placement: .topBarTrailing) {
						let reference = CatalogReference(
							id: concept.id,
							name: concept.name,
							category: .concepts
						)
						BookmarkToolbarButton(reference: reference)
					}
				}
			} else {
				ContentUnavailableView("Concept Not Found", systemImage: "book.closed")
					.toolbar {
						ToolbarItem(placement: .topBarTrailing) {
							Button {
								navigation.libraryPath = [.category(.concepts)]
							} label: {
								Label("Go Back", systemImage: "chevron.left")
							}
							.accessibilityIdentifier("concept.notFound.back")
						}
					}
			}
		}
	}
}
