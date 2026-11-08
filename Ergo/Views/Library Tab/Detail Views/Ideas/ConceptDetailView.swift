import SwiftUI

struct ConceptDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog
	@Environment(NavigationManager.self) private var navigation

	@State private var hasScrolled = false
	@State private var isOpening = true

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var configuration = detailViewConf
				configuration.palette = [LibraryContent.concepts.themeColor.toSIMD3, LibraryContent.concepts.themeColor.toSIMD3]
				return configuration
			}())
				.ignoresSafeArea()

			if let concept = catalog.concepts.concepts.first(where: { $0.id == id }) {
				// Derive indices dynamically so they shift cleanly if something is missing
				let hasOrigin = concept.origin?.isEmpty == false

				let originIndex = 4
				let examplesIndex = originIndex + (hasOrigin ? 1 : 0)
				let misreadingsIndex = examplesIndex + 1
				let criticismsIndex = misreadingsIndex + 1
				let lookalikesIndex = criticismsIndex + 1
				let relatedIndex = lookalikesIndex + 1
				let tagsIndex = relatedIndex + 1

				ScrollView {
					LazyVStack(alignment: .leading) {
						AliasTitle(name: concept.name, aliases: concept.aliases)

						Spacer()
							.frame(height: 10)

						Text(concept.summary)
							.textSelection(.enabled)
							.lineLimit(10)
							.bounceOnAppear(after: 1)

						RelatedSection(list: concept.keyFigures, title: "Key Figures")
							.padding(.top)
							.bounceOnAppear(after: 2)

						Text(concept.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
							.bounceOnAppear(after: 3)

						if let origin = concept.origin, !origin.isEmpty {
							NotesSection(list: [origin], title: "Origin")
								.padding(.top)
								.bounceOnAppear(after: originIndex)
						}

						ExamplesSection(list: concept.examples)
							.padding(.top)
							.bounceOnAppear(after: examplesIndex)

						NotesSection(list: concept.commonMisreadings, title: "Common Misreadings")
							.padding(.top)
							.bounceOnAppear(after: misreadingsIndex)

						NotesSection(list: concept.criticisms, title: "Criticisms")
							.padding(.top)
							.bounceOnAppear(after: criticismsIndex)

						LookalikeSection(list: concept.lookalikes)
							.padding(.top)
							.bounceOnAppear(after: lookalikesIndex)

						RelatedSection(list: concept.related)
							.padding(.top)
							.bounceOnAppear(after: relatedIndex)

						let tags = concept.tags.map { tag in
							CatalogTag(
								id: "concepts.\(tag.rawValue)",
								title: tag.title,
								route: .concepts(filter: tag)
							)
						}
						TagSection(list: tags)
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
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(concept.name, category: "Concepts", hasScrolled: hasScrolled)
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(concept.name.capitalized)
				.toolbar {
					LibraryDetailMenu(reference: CatalogReference(
						id: concept.id,
						name: concept.name,
						category: .concepts
					))
				}
			} else {
				ContentUnavailableView("Concept Not Found", systemImage: "book.closed")
					.toolbar {
						ToolbarItem(placement: .topBarTrailing) {
							Button {
								navigation.libraryPath.removeLast()
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
