//
//  AddToChatSheet.swift
//  Ergo
//

import SwiftUI

/// Which chat something's being attached to
struct AddToChatSheet: View {
	let content: AskAttachment.Content

	@Environment(AskStore.self)
	private var store

	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		NavigationStack {
			List {
				Section {
					Button {
						store.startChat(attaching: content)
						finish()
					} label: {
						newChatRow
					}
					.buttonStyle(.plain)
					.accessibilityIdentifier("addToChat.new")
				}

				if !store.listedConversations.isEmpty {
					Section("Chats") {
						ForEach(store.listedConversations) { conversation in
							Button {
								store.attach(content, to: conversation.id)
								store.open(conversation.id)
								finish()
							} label: {
								AskHistoryRow(conversation: conversation, isAnswering: store.runs[conversation.id] != nil)
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
			.navigationTitle("Add to Chat")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(role: .cancel) {
						navigation.dismissSheet()
					}
					.accessibilityIdentifier("addToChat.cancel")
				}
			}
		}
		.presentationDetents([.medium, .large])
	}

	/// A new chat that already has things waiting is the one this joins, so it says so
	private var newChatRow: some View {
		let waiting = store.unsentDraft.flatMap { store.attachments[$0.id]?.count }

		return HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text("New Chat")
					.font(.headline)

				if let waiting {
					Text("^[\(waiting) attachment](inflect: true) waiting")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			}

			Spacer(minLength: 0)

			Image(systemName: waiting == nil ? "square.and.pencil" : "paperclip")
				.foregroundStyle(.tint)
		}
		.contentShape(Rectangle())
	}

	private func finish() {
		// In this order, since closing it means closing what's on the tab it was opened from
		navigation.dismissSheet()
		navigation.selectedTab = .ask
	}
}
