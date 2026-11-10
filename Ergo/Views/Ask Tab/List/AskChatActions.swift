//
//  AskChatActions.swift
//  Ergo
//

import SwiftUI

/// What's been attached, pin, archive and delete, for an open chat's menu and a chat's context menu
struct AskChatActions: View {
	let conversation: AskConversation
	let showAttachments: () -> Void
	let delete: () -> Void

	@Environment(AskStore.self)
	private var store

	var body: some View {
		if !conversation.sentAttachments.isEmpty {
			Section {
				Button("Attachments", systemImage: "paperclip", action: showAttachments)
					.accessibilityIdentifier("ask.attachments")
			}
		}

		Section {
			// An archived chat isn't in the list for a pin to do anything
			if conversation.isArchived != true {
				PinButton(isPinned: conversation.isPinned == true) {
					store.setPinned(conversation.isPinned != true, conversation.id)
				}
				.accessibilityIdentifier("ask.pin")
			}

			ArchiveButton(isArchived: conversation.isArchived == true) {
				store.setArchived(conversation.isArchived != true, conversation.id)
			}
			.accessibilityIdentifier("ask.archive")
		}

		Section {
			Button("Delete", systemImage: "trash", role: .destructive, action: delete)
				.accessibilityIdentifier("ask.delete")
		}
	}
}

/// A chat in a list, with its swipes and context menu
struct AskChatRow: View {
	let conversation: AskConversation

	/// Archived chats aren't renamed
	var rename: (() -> Void)?
	let open: () -> Void
	let showAttachments: () -> Void

	@Environment(AskStore.self)
	private var store

	var body: some View {
		Button(action: open) {
			AskHistoryRow(conversation: conversation, isAnswering: store.runs[conversation.id] != nil)
		}
		.buttonStyle(.plain)
		.swipeActions {
			Button("Delete", systemImage: "trash", role: .destructive) {
				store.delete(conversation.id)
			}

			ArchiveButton(isArchived: conversation.isArchived == true) {
				store.setArchived(conversation.isArchived != true, conversation.id)
			}
		}
		.swipeActions(edge: .leading) {
			renameButton

			if conversation.isArchived != true {
				PinButton(isPinned: conversation.isPinned == true) {
					store.setPinned(conversation.isPinned != true, conversation.id)
				}
			}
		}
		.contextMenu {
			renameButton

			AskChatActions(
				conversation: conversation,
				showAttachments: showAttachments,
				delete: { store.delete(conversation.id) }
			)
		}
	}

	@ViewBuilder
	private var renameButton: some View {
		if let rename {
			Button("Rename", systemImage: "pencil", action: rename)
				.tint(.orange)
		}
	}
}

/// The chats that have been put away. Opening one closes this and pushes it onto the Ask tab like any other.
struct AskArchivedChatsSheet: View {
	@Environment(AskStore.self)
	private var store

	@Environment(\.dismiss)
	private var dismiss

	@State private var attachmentsOf: AskConversation?

	var body: some View {
		NavigationStack {
			List {
				ForEach(store.archivedConversations) { conversation in
					AskChatRow(
						conversation: conversation,
						open: {
							dismiss()
							store.open(conversation.id)
						},
						showAttachments: { attachmentsOf = conversation }
					)
				}
			}
			.overlay {
				if store.archivedConversations.isEmpty {
					ContentUnavailableView("No Archived Chats", systemImage: "archivebox")
				}
			}
			.navigationTitle("Archived")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(role: .close) {
						dismiss()
					}
					.accessibilityIdentifier("ask.archived.close")
				}
			}
			.sheet(item: $attachmentsOf) { AskAttachmentsSheet(conversation: $0, leaving: { dismiss() }) }
		}
		.presentationDetents([.medium, .large])
	}
}
