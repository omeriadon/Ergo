//
//  AskChatsListView.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import SwiftUI

struct AskChatsListView: View {
	@Environment(AskStore.self)
	private var store

	@Environment(\.dismiss)
	private var dismiss

	var body: some View {
		NavigationStack {
			List {
				ForEach(store.sortedConversations) { conversation in
					Button {
						store.open(conversation.id)
						dismiss()
					} label: {
						AskHistoryRow(conversation: conversation, isAnswering: store.runs[conversation.id] != nil)
					}
					.buttonStyle(.plain)
					.swipeActions {
						Button("Delete", systemImage: "trash", role: .destructive) {
							store.delete(conversation.id)
						}
					}
				}
			}
			.overlay {
				if store.conversations.isEmpty {
					ContentUnavailableView("No Chats", systemImage: "clock.arrow.circlepath")
				}
			}
			.navigationTitle("History")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(role: .close) {
						dismiss()
					}
				}
			}
		}
		.presentationDetents([.medium, .large])
	}
}

private struct AskHistoryRow: View {
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
