import Defaults
import SwiftUI

struct FallacyDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog
	@Environment(NavigationManager.self) private var navigation

	@State private var hasScrolled = false
	@State private var isOpening = true

	@Default(.bookmarks) var bookmarks

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var configuration = detailViewConf
				configuration.palette = [LibraryContent.fallacies.themeColor.toSIMD3, LibraryContent.fallacies.themeColor.toSIMD3]
				return configuration
			}())
				.ignoresSafeArea()

			if let fallacy = catalog.fallacies.fallacies.first(where: { $0.id == id }) {
				// Derive indices dynamically so they shift cleanly if something is missing
				let hasCriteria = fallacy.detectionCriteria?.isEmpty == false

				let criteriaIndex = 2
				let bodyIndex = criteriaIndex + (hasCriteria ? 1 : 0)
				let examplesIndex = bodyIndex + 1
				let doesNotCountIndex = examplesIndex + 1
				let lookalikesIndex = doesNotCountIndex + 1
				let relatedIndex = lookalikesIndex + 1
				let tagsIndex = relatedIndex + 1

				ScrollView {
					LazyVStack(alignment: .leading) {
						AliasTitle(name: fallacy.name, aliases: fallacy.aliases)

						Spacer()
							.frame(height: 10)

						Text(fallacy.summary)
							.textSelection(.enabled)
							.lineLimit(10)
							.bounceOnAppear(after: 1)

						if let criteria = fallacy.detectionCriteria, !criteria.isEmpty {
							VStack(alignment: .leading, spacing: 12) {
								Text("How to identify")
									.textCase(.uppercase)
									.foregroundStyle(.secondary)

								HStack {
									Image(systemName: "checklist")
										.font(.title)
									Text(criteria)
										.textSelection(.enabled)
								}
							}
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
							.bounceOnAppear(after: criteriaIndex)
						}

						Text(fallacy.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
							.bounceOnAppear(after: bodyIndex)

						ExamplesSection(list: fallacy.examples)
							.padding(.top)
							.bounceOnAppear(after: examplesIndex)

						NotesSection(list: fallacy.doesNotCountWhen, title: "Does Not Count When")
							.padding(.top)
							.bounceOnAppear(after: doesNotCountIndex)

						LookalikeSection(list: fallacy.lookalikes)
							.padding(.top)
							.bounceOnAppear(after: lookalikesIndex)

						RelatedSection(list: fallacy.related)
							.padding(.top)
							.bounceOnAppear(after: relatedIndex)

						let tags = fallacy.tags.map { tag in
							CatalogTag(
								id: "fallacies.\(tag.rawValue)",
								title: tag.title,
								route: .fallacies(filter: tag)
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
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(fallacy.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(fallacy.name, category: "Fallacies", hasScrolled: hasScrolled)
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
