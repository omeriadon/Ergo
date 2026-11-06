import SwiftUI

struct ArgumentDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog
	@Environment(NavigationManager.self) private var navigation

	@State private var hasScrolled = false

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var configuration = detailViewConf
				configuration.palette = [Color.teal.toSIMD3, Color.teal.toSIMD3]
				return configuration
			}())
				.ignoresSafeArea()

			if let argument = catalog.arguments.arguments.first(where: { $0.id == id }) {
				ScrollView {
					VStack(alignment: .leading) {
						AliasTitle(name: argument.name, aliases: argument.aliases)

						Spacer()
							.frame(height: 10)

						Text(argument.summary)
							.textSelection(.enabled)
							.lineLimit(10)

						RelatedSection(list: argument.keyFigures, title: "Key Figures")
							.padding(.top)

						Text(argument.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)

						if let origin = argument.origin, !origin.isEmpty {
							NotesSection(list: [origin], title: "Origin")
								.padding(.top)
						}

						NotesSection(list: argument.premises, title: "Premises")
							.padding(.top)

						if !argument.conclusion.isEmpty {
							NotesSection(list: [argument.conclusion], title: "Conclusion")
								.padding(.top)
						}

						NotesSection(list: argument.assumptions, title: "Assumptions")
							.padding(.top)

						let objections = argument.objections.map { objection in
							Example(
								text: "Objection: \(objection.objection)",
								note: "Reply: \(objection.reply)"
							)
						}
						ExamplesSection(list: objections, title: "Objections & Replies")
							.padding(.top)

						ExamplesSection(list: argument.examples)
							.padding(.top)

						RelatedSection(list: argument.related)
							.padding(.top)

						let tags = argument.tags.map { tag in
							CatalogTag(
								id: "arguments.\(tag.rawValue)",
								title: tag.title,
								route: .arguments(filter: tag)
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
