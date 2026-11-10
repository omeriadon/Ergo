//
//  AskChatsListView.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import Defaults
import SwiftUI

struct AskChatsListView: View {
	@Environment(AskStore.self)
	private var store

	private var isChatOpen: Binding<Bool> {
		Binding(
			get: { store.isChatOpen },
			set: {
				if !$0 {
					store.closeChat()
				}
			}
		)
	}

	@State private var renaming: Renaming<AskConversation.ID>?

	@State private var attachmentsOf: AskConversation?

	/// The list has been pulled down past its top
	@State private var revealsArchived = false

	@State private var isShowingArchived = false

	/// Hidden until it's pulled into view, unless there'd be nothing else to see
	private var showsArchivedRow: Bool {
		!store.archivedConversations.isEmpty && (revealsArchived || store.listedConversations.isEmpty)
	}

	private var chats: some View {
		List {
			if showsArchivedRow {
				ArchivedRow(count: store.archivedConversations.count) {
					isShowingArchived = true
				}
			}

			ForEach(store.listedConversations) { conversation in
				AskChatRow(
					conversation: conversation,
					rename: { renaming = Renaming(id: conversation.id, name: conversation.name) },
					open: { store.open(conversation.id) },
					showAttachments: { attachmentsOf = conversation }
				)
			}
		}
		.revealsArchived($revealsArchived, hasArchived: !store.archivedConversations.isEmpty)
	}

	var body: some View {
		NavigationStack {
			chats
				.renameAlert("Rename Chat", renaming: $renaming) { id, name in
					store.rename(id, to: name)
				}
				.sheet(item: $attachmentsOf) { AskAttachmentsSheet(conversation: $0) }
				.sheet(isPresented: $isShowingArchived) { AskArchivedChatsSheet() }
				.navigationDestination(isPresented: isChatOpen) {
					AskThreadView()
				}
				.overlay {
					if store.conversations.isEmpty {
						ContentUnavailableView("No Chats", systemImage: "clock.arrow.circlepath")
					}
				}
				.toolbarTitleVire("Ask", "bubble.left.and.text.bubble.right")
		}
		.presentationDetents([.medium, .large])
	}
}

struct AskHistoryRow: View {
	let conversation: AskConversation
	let isAnswering: Bool

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text(conversation.title)
					.font(.headline)
					.lineLimit(1)

				Text(conversation.modified, format: .relative(presentation: .named))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)

			if conversation.isPinned == true {
				Image(systemName: "pin.fill")
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityLabel("Pinned")
			}

			if isAnswering {
				ProgressView()
					.accessibilityLabel("Answering")
			}

			Image(systemName: "chevron.right")
				.foregroundStyle(.secondary)
		}
		.contentShape(Rectangle())
	}
}

extension AnyTransition {
	/// A message rises out of the box it was written in, growing from the corner the send button's at
	static var askSend: AnyTransition {
		.modifier(
			active: AskSendEffect(progress: 0),
			identity: AskSendEffect(progress: 1)
		)
	}
}

private struct AskSendEffect: ViewModifier {
	let progress: Double

	func body(content: Content) -> some View {
		content
			.scaleEffect(0.85 + 0.15 * progress, anchor: .bottomTrailing)
			.offset(y: 60 * (1 - progress))
			.opacity(progress)
			.blur(radius: 6 * (1 - progress))
	}
}
