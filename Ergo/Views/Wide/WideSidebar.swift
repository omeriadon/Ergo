//
//  WideSidebar.swift
//  Ergo
//

import SwiftUI

/// The wide layout's sidebar: every section and what's in it. Its selection is read from what's open and written back
/// through the same methods the tabs use (`NavigationManager.sidebarSelection` and `select`), so it holds no state of its own.
struct WideSidebar: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(ScratchpadStore.self)
	private var scratchpadStore

	@Environment(AskStore.self)
	private var askStore

	@Environment(TranslationAccount.self)
	private var account

	/// One for every kind, so there's only one alert on the list
	@State private var renaming: Renaming<SidebarItem>?

	/// A shared board waiting on the person to say so, since only its owner can undo it
	@State private var removing: Board?

	@State private var attachmentsOf: AskConversation?

	private var selection: Binding<SidebarItem?> {
		Binding(
			get: {
				navigation.sidebarSelection(
					boards: boardStore,
					scratchpads: scratchpadStore,
					ask: askStore,
					isSignedIn: account.isSignedInHere
				)
			},
			set: { item in
				guard let item else { return }
				navigation.select(
					item,
					boards: boardStore,
					scratchpads: scratchpadStore,
					ask: askStore,
					isSignedIn: account.isSignedInHere
				)
			}
		)
	}

	private var renameTitle: LocalizedStringKey {
		switch renaming?.id {
			case .board?: "Rename Board"
			case .scratchpad?: "Rename Scratchpad"
			case .chat?: "Rename Chat"
			default: "Rename"
		}
	}

	private var list: some View {
		List(selection: selection) {
			WideSidebarBoards(renaming: $renaming, removing: $removing)
			WideSidebarLogic(renaming: $renaming)
			WideSidebarAsk(renaming: $renaming, attachmentsOf: $attachmentsOf)
			WideSidebarLibrary()
		}
		.listStyle(.sidebar)
	}

	var body: some View {
		list
			.navigationTitle("Ergo")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Settings", systemImage: "gear") {
						navigation.presentSheet(.settings(id: "3refd"))
					}
				}
			}
			.renameAlert(renameTitle, renaming: $renaming) { item, name in
				rename(item, to: name)
			}
			.boardRemovalDialog($removing)
			.sheet(item: $attachmentsOf) { AskAttachmentsSheet(conversation: $0) }
	}

	private func rename(_ item: SidebarItem, to name: String) {
		switch item {
			case let .board(id):
				boardStore.rename(id, to: name)
			case let .scratchpad(id):
				scratchpadStore.rename(id, to: name)
			case let .chat(id):
				askStore.rename(id, to: name)
			case .course, .ask, .libraryHome, .library, .bookmarks:
				break
		}
	}
}

/// A section's title, with the button that adds to it
struct WideSidebarHeader<Actions: View>: View {
	let title: String
	let actions: Actions

	init(_ title: String, @ViewBuilder actions: () -> Actions) {
		self.title = title
		self.actions = actions()
	}

	var body: some View {
		HStack {
			Text(title)

			Spacer(minLength: 0)

			actions
				.labelStyle(.iconOnly)
				.buttonStyle(.borderless)
		}
	}
}
