//
//  PhilosopherDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import SwiftUI

struct PhilosopherDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	@State private var showAliases = false

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var conf = detailViewConf
				conf.palette = [
					Color.red.toSIMD3,
					Color.red.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let philosopher = catalog.philosophers.philosophers.first(where: { $0.id == id }) {
				ScrollView {
					VStack(alignment: .leading) {
						GeometryReader { geo in
							ZStack {
								Image(philosopher.id)
									.resizable()
									.aspectRatio(contentMode: .fill)
									.clipShape(Circle())

								LiquidLens(
									isLifted: true,
									animated: false,
									configuration: .init(
										warpsContentBelow: true,
										restingBackgroundColor: .white.withAlphaComponent(0),
										liftedDisplacement: 100
									)
								)
								.frame(width: geo.size.width, height: geo.size.width)
							}
							.frame(width: geo.size.width, height: geo.size.width)
						}
						.aspectRatio(1, contentMode: .fit)
						.padding()

						Text(philosopher.name)
							.foregroundStyle(.white)
							.font(.largeTitle.bold())
							.frame(maxWidth: .infinity, alignment: .center)
							.lineLimit(2)

						HStack {
							Text(philosopher.birthYear.description)
							Text(philosopher.deathYear == nil ? "-" : "to")
							if let deathYear = philosopher.deathYear {
								Text(deathYear.description)
							} else {
								Text("present")
							}
						}
						.frame(maxWidth: .infinity, alignment: .center)
						.monospaced()
						.fontDesign(.monospaced)
						.foregroundStyle(.secondary)

						Spacer()
							.frame(height: 60)

						Text(philosopher.summary)
							.lineLimit(10)

						Text(philosopher.body)
							.padding(12)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)

						related
							.padding(.top)

						Spacer()
							.frame(height: 40)
					}
					.padding(.horizontal)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(philosopher.name.capitalized)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					ToolbarItem(placement: .topBarTrailing) {
						let reference = CatalogReference(
							id: philosopher.id,
							name: philosopher.name,
							category: .philosophers
						)

						let isBookmarked = bookmarks.contains(reference)

						Button {
							withAnimation(.easeInOut) {
								if isBookmarked {
									bookmarks.remove(reference)
								} else {
									bookmarks.insert(reference)
								}
							}
						} label: {
							Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
								.contentTransition(.symbolEffect(.replace))
						}
						.buttonStyle(.glassProminent)
						.tint(isBookmarked ? .accentColor : .clear)
					}
				}

			} else {
				Text("Philosopher not found")

				Button {
					navigation.libraryPath = [.category(.philosophers)]
				} label: {
					Text("Go Back")
				}
			}
		}
	}

	@ContentBuilder
	var related: some View {
		if let philosopher = catalog.philosophers.philosophers.first(where: { $0.id == id }) {
			if !philosopher.related.isEmpty {
				VStack(alignment: .leading, spacing: 13) {
					Text("Related")
						.textCase(.uppercase)
						.foregroundStyle(.accent)

					VStack(alignment: .leading, spacing: 4) {
						ForEach(philosopher.related, id: \.id) { target in
							let isBookmarked = bookmarks.contains(target)

							NavigationLink(value: target.route) {
								HStack {
									Text(target.name)
									Spacer()
									Image(systemName: "chevron.right")
								}
								.contextMenu {
									Button {
										withAnimation(.easeInOut) {
											if isBookmarked {
												bookmarks.remove(target)
											} else {
												bookmarks.insert(target)
											}
										}
									} label: {
										if isBookmarked {
											Label("Remove Bookmark", systemImage: "bookmark.fill")
										} else {
											Label("Bookmark", systemImage: "bookmark")
										}
									}
								} preview: {
									LibraryDetailView(category: target.category, id: target.id)
										.environment(catalog)
										.environment(navigation)
								}
							}
						}
					}
				}
				.padding(12)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
			}
		}
	}
}
