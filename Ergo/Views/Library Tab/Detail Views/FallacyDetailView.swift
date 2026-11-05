import Defaults
import SwiftUI

struct FallacyDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog
	@Environment(NavigationManager.self) private var navigation

	@State private var hasScrolled = false

	@Default(.bookmarks) var bookmarks

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

						if let criteria = fallacy.detectionCriteria, !criteria.isEmpty {
							VStack(alignment: .leading, spacing: 12) {
								Text("How to identify")
									.textCase(.uppercase)
									.foregroundStyle(.secondary)

								HStack {
									Image(systemName: "checklist")
										.font(.title)
									Text(criteria)
								}
							}
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
						}

						Text(fallacy.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)

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
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.richNavigationTitle(height: 40, width: 360) {
					VStack {
						Text(hasScrolled ? fallacy.name : "")

						Text(hasScrolled ? "Fallacies" : "")
							.textCase(.uppercase)
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
					.contentTransition(.numericText())
					.animation(.easeInOut(duration: 0.2), value: hasScrolled)
				}
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
								navigation.libraryPath.removeLast()
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
