//
//  PhilosopherDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import SwiftUI

struct PhilosopherDetailView: View {
	let id: String

	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var showAliases = false

	@State private var hasScrolled = false
	@State private var isOpening = true

	var body: some View {
		ZStack {
			DitherView(configuration: {
				var conf = detailViewConf
				conf.palette = [
					LibraryContent.philosophers.themeColor.toSIMD3,
					LibraryContent.philosophers.themeColor.toSIMD3,
				]
				return conf
			}())
				.ignoresSafeArea()

			if let philosopher = catalog.philosophers.philosophers.first(where: { $0.id == id }) {
				ScrollView {
					LazyVStack(alignment: .leading) {
						GeometryReader { geo in
							ZStack {
								Image(philosopher.id)
									.resizable()
									.aspectRatio(contentMode: .fill)
									.clipShape(Circle())

								#if os(iOS)
									LiquidLens(
										isLifted: true,
										animated: false,
										configuration: .init(
											style: 0,
											warpsContentBelow: true,
											restingBackgroundColor: .white.withAlphaComponent(0),
											liftedDisplacement: 100,
											innerShadowOpacity: 0
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
								#endif
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
							.textSelection(.enabled)
							.lineLimit(10)
							.bounceOnAppear(after: 1)

						Text(philosopher.body)
							.padding(12)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
							.padding(.top)
							.bounceOnAppear(after: 2)

						RelatedSection(list: philosopher.related)
							.padding(.top)
							.bounceOnAppear(after: 3)

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
				.navigationTitle(philosopher.name.capitalized)
				.onScrollGeometryChange(for: Bool.self) { geometry in
					geometry.contentOffset.y + geometry.contentInsets.top > 480
				} action: { _, newValue in
					hasScrolled = newValue
				}
				.libraryDetailTitle(philosopher.name, category: "Philosophers", hasScrolled: hasScrolled)
				.toolbar {
					ToolbarItem(placement: .title) {
						Text("")
					}

					LibraryDetailMenu(reference: CatalogReference(
						id: philosopher.id,
						name: philosopher.name,
						category: .philosophers
					))
				}

			} else {
				Text("Philosopher not found")

				Button {
					navigation.libraryPath.removeLast()
				} label: {
					Text("Go Back")
				}
			}
		}
	}
}
