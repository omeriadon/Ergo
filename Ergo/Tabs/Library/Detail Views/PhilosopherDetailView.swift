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

	@State private var hasScrolled = false

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var conf = detailViewConf
				conf.palette = [
					Color.purple.toSIMD3,
					Color.purple.toSIMD3,
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
									),
									configure: { handle in
										guard let flex = handle.value(for: .flexInteraction) as? NSObject else {
											return
										}

										handle.setValue(
											0,
											forKeyPath: "preferredFlexSources",
											on: flex
										)
									}
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
							Text("\(abs(philosopher.birthYear).description)\(philosopher.birthYear < 0 ? " BC" : "")")
							Text(philosopher.deathYear == nil ? "-" : "to")
							if let deathYear = philosopher.deathYear {
								Text("\(abs(deathYear).description)\(deathYear < 0 ? " BC" : "")")
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

						RelatedSection(list: philosopher.related)
							.padding(.top)

						Spacer()
							.frame(height: 40)
					}
					.padding(.horizontal)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.scrollEdgeEffectStyle(.soft, for: .all)
				.navigationTitle(philosopher.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 70
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.richNavigationTitle(height: 40, width: 360) {
					VStack {
						Text(hasScrolled ? philosopher.name : "")

						Text(hasScrolled ? "Philosophers" : "")
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
}
