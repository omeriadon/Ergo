import SwiftUI

struct FallacyDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog
	@Environment(NavigationManager.self) private var navigation

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var configuration = detailViewConf
				configuration.palette = [Color.blue.toSIMD3, Color.blue.toSIMD3]
				return configuration
			}())
				.ignoresSafeArea()

			if let fallacy = catalog.fallacies.fallacies.first(where: { $0.id == id }) {
				ScrollView {
					VStack(alignment: .leading) {
						AliasTitle(name: fallacy.name, aliases: fallacy.aliases)

						Spacer()
							.frame(height: 10)

						Text(fallacy.summary)
							.lineLimit(10)

						Text(fallacy.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)

						if let criteria = fallacy.detectionCriteria, !criteria.isEmpty {
							NotesSection(list: [criteria], title: "Detection Criteria")
								.padding(.top)
						}

						ExamplesSection(list: fallacy.examples)
							.padding(.top)

						NotesSection(list: fallacy.doesNotCountWhen, title: "Does Not Count When")
							.padding(.top)

						LookalikeSection(list: fallacy.lookalikes)
							.padding(.top)

						RelatedSection(list: fallacy.related)
							.padding(.top)

						let tags = fallacy.tags.map { tag in
							CatalogTag(
								id: "fallacies.\(tag.rawValue)",
								title: tag.title,
								route: .fallacies(filter: tag)
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
				.navigationTitle(fallacy.name.capitalized)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					ToolbarItem(placement: .topBarTrailing) {
						let reference = CatalogReference(
							id: fallacy.id,
							name: fallacy.name,
							category: .fallacies
						)
						BookmarkToolbarButton(reference: reference)
					}
				}
			} else {
				ContentUnavailableView("Fallacy Not Found", systemImage: "repeat.badge.xmark")
					.toolbar {
						ToolbarItem(placement: .topBarTrailing) {
							Button {
								navigation.libraryPath = [.category(.fallacies)]
							} label: {
								Label("Go Back", systemImage: "chevron.left")
							}
							.accessibilityIdentifier("fallacy.notFound.back")
						}
					}
			}
		}
	}
}
