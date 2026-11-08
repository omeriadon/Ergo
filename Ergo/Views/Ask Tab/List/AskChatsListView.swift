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

	var body: some View {
		NavigationStack {
			List {
				ForEach(store.sortedConversations) { conversation in
					Button {
						store.open(conversation.id)
					} label: {
						AskHistoryRow(conversation: conversation, isAnswering: store.runs[conversation.id] != nil)
					}
					.buttonStyle(.plain)
					.swipeActions {
						Button("Delete", systemImage: "trash", role: .destructive) {
							store.delete(conversation.id)
						}
					}
					.swipeActions(edge: .leading) {
						renameButton(for: conversation)
					}
					.contextMenu {
						renameButton(for: conversation)
					}
				}
			}
			.renameAlert("Rename Chat", renaming: $renaming) { id, name in
				store.rename(id, to: name)
			}
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

private extension AskChatsListView {
	func renameButton(for conversation: AskConversation) -> some View {
		Button("Rename", systemImage: "pencil") {
			renaming = Renaming(id: conversation.id, name: conversation.name)
		}
		.tint(.orange)
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

			if isAnswering {
				ProgressView()
					.accessibilityLabel("Answering")
			}
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
