//
//  SymbolsView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import FuzzyMatch
import SwiftUI

struct SymbolsView: View {
	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@State private var searchTerm = ""

	@State private var searchPresented = false

	var body: some View {
		List {
			if searchPresented {
				if searchTerm.isEmpty {
					VStack(spacing: 20) {
						Image("Ergo")
							.resizable()
							.aspectRatio(contentMode: .fit)
							.foregroundStyle(.accent.gradient)
							.frame(width: 50, height: 50)
						Text("Search Something")
							.font(.title3)
					}
					.padding(.top, 90)
					.listRowBackground(Color.clear)
					.frame(maxWidth: .infinity, alignment: .center)
					.transition(.opacity)
				} else {
					let results = searchSymbols(catalog.logicSymbols.symbols, query: searchTerm)

					ForEach(results) { symbol in
						NavigationLink(value: LibraryRoute.detail(category: .symbols, id: symbol.id)) {
							HStack(alignment: .center) {
								Text(symbol.glyph)
									.font(.title)
									.fontDesign(.monospaced)
									.monospaced()
									.frame(width: symbol.glyph.count < 3 ? 40 : 110, alignment: .leading)

								Text(symbol.name)

								Spacer()
							}
						}
						.transition(.opacity)
					}
				}

			} else {
				ForEach(catalog.logicSymbols.symbols) { symbol in
					NavigationLink(value: LibraryRoute.detail(category: .symbols, id: symbol.id)) {
						HStack(alignment: .center) {
							Text(symbol.glyph)
								.font(.title)
								.fontDesign(.monospaced)
								.monospaced()
								.frame(width: symbol.glyph.count < 3 ? 40 : 110, alignment: .leading)

							Text(symbol.name)

							Spacer()
						}
					}
				}
			}
		}
		.scrollEdgeEffectStyle(.soft, for: .all)
		.buttonStyle(.plain)
		.toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
		.searchable(
			text: $searchTerm,
			isPresented: $searchPresented,
			placement: .navigationBarDrawer(displayMode: .always),
			prompt: "Search logic symbols"
		)
		.animation(.easeInOut(duration: 0.1), value: "\(searchPresented)\(searchTerm)")
		.navigationTitle("Symbols")
		.toolbar {
			ToolbarItem(placement: .title) {
				Text("Symbols")
			}
		}
	}

	func searchSymbols(
		_ symbols: [LogicSymbol],
		query: String
	) -> [LogicSymbol] {
		guard !query.isEmpty else { return symbols }

		let matcher = FuzzyMatcher()
		let prepared = matcher.prepare(query)
		var buffer = matcher.makeBuffer()

		return symbols.compactMap { symbol -> (LogicSymbol, Double)? in
			let fields: [(String, Double)] = [
				(symbol.name, 1.0),
				(symbol.glyph, 1.0),
				(symbol.body, 0.5),
				(symbol.summary, 0.5),
			] + symbol.aliases.map { ($0, 0.9) }

			let score = fields.compactMap { text, weight in
				matcher.score(
					text,
					against: prepared,
					buffer: &buffer
				).map { $0.score * weight }
			}.max()

			guard let score else { return nil }
			return (symbol, score)
		}
		.sorted { $0.1 > $1.1 }
		.map(\.0)
	}
}
