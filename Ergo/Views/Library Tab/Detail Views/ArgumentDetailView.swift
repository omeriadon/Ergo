import SwiftUI

struct ArgumentDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog
	@Environment(NavigationManager.self) private var navigation

	@State private var hasScrolled = false
	@State private var isOpening = true

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var configuration = detailViewConf
				configuration.palette = [LibraryContent.arguments.themeColor.toSIMD3, LibraryContent.arguments.themeColor.toSIMD3]
				return configuration
			}())
				.ignoresSafeArea()

			if let argument = catalog.arguments.arguments.first(where: { $0.id == id }) {
				// 1. Check which optional sections actually exist
				let hasOrigin = argument.origin?.isEmpty == false
				let hasConclusion = !argument.conclusion.isEmpty

				// 2. Derive indices dynamically so they shift cleanly if something is missing
				let premisesIndex = hasOrigin ? 5 : 4
				let conclusionIndex = premisesIndex + 1
				let assumptionsIndex = conclusionIndex + (hasConclusion ? 1 : 0)
				let objectionsIndex = assumptionsIndex + 1
				let examplesIndex = objectionsIndex + 1
				let relatedIndex = examplesIndex + 1
				let tagsIndex = relatedIndex + 1

				ScrollView {
					LazyVStack(alignment: .leading) {
						AliasTitle(name: argument.name, aliases: argument.aliases)

						Spacer()
							.frame(height: 10)

						Text(argument.summary)
							.textSelection(.enabled)
							.lineLimit(10)
							.bounceOnAppear(after: 1)

						RelatedSection(list: argument.keyFigures, title: "Key Figures")
							.padding(.top)
							.bounceOnAppear(after: 2)

						Text(argument.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
							.bounceOnAppear(after: 3)

						if let origin = argument.origin, !origin.isEmpty {
							NotesSection(list: [origin], title: "Origin")
								.padding(.top)
								.bounceOnAppear(after: 4)
						}

						NotesSection(list: argument.premises, title: "Premises")
							.padding(.top)
							.bounceOnAppear(after: premisesIndex)

						if !argument.conclusion.isEmpty {
							NotesSection(list: [argument.conclusion], title: "Conclusion")
								.padding(.top)
								.bounceOnAppear(after: conclusionIndex)
						}

						NotesSection(list: argument.assumptions, title: "Assumptions")
							.padding(.top)
							.bounceOnAppear(after: assumptionsIndex)

						let objections = argument.objections.map { objection in
							Example(
								text: "Objection: \(objection.objection)",
								note: "Reply: \(objection.reply)"
							)
						}

						ExamplesSection(list: objections, title: "Objections & Replies")
							.padding(.top)
							.bounceOnAppear(after: objectionsIndex)

						ExamplesSection(list: argument.examples)
							.padding(.top)
							.bounceOnAppear(after: examplesIndex)

						RelatedSection(list: argument.related)
							.padding(.top)
							.bounceOnAppear(after: relatedIndex)

						let tags = argument.tags.map { tag in
							CatalogTag(
								id: "arguments.\(tag.rawValue)",
								title: tag.title,
								route: .arguments(filter: tag)
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
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(argument.name, category: "Arguments", hasScrolled: hasScrolled)
				.navigationTitle(argument.name.capitalized)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					ToolbarItem(placement: .topBarTrailing) {
						let reference = CatalogReference(
							id: argument.id,
							name: argument.name,
							category: .arguments
						)
						BookmarkToolbarButton(reference: reference)
					}
				}
			} else {
				ContentUnavailableView("Argument Not Found", systemImage: "text.bubble")
					.toolbar {
						ToolbarItem(placement: .topBarTrailing) {
							Button {
								navigation.libraryPath.removeLast()
							} label: {
								Label("Go Back", systemImage: "chevron.left")
							}
							.accessibilityIdentifier("argument.notFound.back")
						}
					}
			}
		}
	}
}
