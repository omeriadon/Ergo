//
//  TagSection.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import SwiftUI

struct TagSection: View {
	@Environment(CatalogStore.self) private var catalog

	@Environment(NavigationManager.self)
	private var navigation

	@Default(.bookmarks) var bookmarks

	let list: [CatalogTag]

	var body: some View {
		if !list.isEmpty {
			VStack(alignment: .leading, spacing: 13) {
				Text("Tags")
					.textCase(.uppercase)
					.foregroundStyle(.secondary)

				VStack(alignment: .leading, spacing: 4) {
					ForEach(list) { tag in
						NavigationLink(value: tag.route) {
							HStack {
								Image(systemName: "tag")
									.imageScale(.small)

								Text(tag.title)
								Spacer()
								Image(systemName: "chevron.right")
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

#Preview {
	TagSection(list: [])
}
