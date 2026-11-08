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

	@Environment(AskStore.self)
	private var store

	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		Button("Add to Chat", systemImage: "bubble.left.and.text.bubble.right") {
			store.startChat(attaching: .library(reference))
			navigation.selectedTab = .ask
		}
		.accessibilityIdentifier("addToChat.\(reference.category).\(reference.id)")
	}
}
