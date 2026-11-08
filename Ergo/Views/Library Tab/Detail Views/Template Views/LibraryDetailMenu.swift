//
//  LibraryDetailMenu.swift
//  Ergo
//

import SwiftUI

/// The overflow menu on every library page
struct LibraryDetailMenu: ToolbarContent {
	let reference: CatalogReference

	var body: some ToolbarContent {
		ToolbarOverflowMenu {
			BookmarkToolbarButton(reference: reference)
			AddToChatButton(reference: reference)
		}
	}
}

private struct AddToChatButton: View {
	let reference: CatalogReference

	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		Button("Add to Chat", systemImage: "bubble.left.and.text.bubble.right") {
			navigation.presentSheet(.addToChat(.library(reference)))
		}
		.accessibilityIdentifier("addToChat.\(reference.category).\(reference.id)")
	}
}
