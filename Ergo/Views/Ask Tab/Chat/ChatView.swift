//
//  ChatView.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import Defaults
import ErgoProtocol
import SwiftUI

/// The open chat. Starting another fades the old one into the new, so each is its own view, tied to its conversation.
struct AskThreadView: View {
	@Environment(AskStore.self)
	private var store

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	var body: some View {
		let id = store.current.id
		ZStack {
			AskConversationView(conversationID: id)
				.id(id)
				.transition(.opacity)
		}
		.animation(reduceMotion ? nil : .smooth, value: id)
		.navigationTitle(store.current.title)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .title) {
				Text(store.current.title)
					.font(.caption)
			}
		}
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("New Chat", systemImage: "square.and.pencil") {
					store.newConversation()
				}
				.accessibilityIdentifier("ask.newChat")
			}
		}
	}
}

private struct AskConversationView: View {
	let conversationID: AskConversation.ID

	@Environment(AskStore.self)
	private var store

	@Environment(TranslationAccount.self)
	private var account

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@Default(.hapticsEnabled) private var hapticsEnabled

	/// The last thing in the list, to scroll to
	private static let end = "ask.end"

	@State private var draft = ""

	/// Goes up with each message sent, for the button's bounce and the haptic
	@State private var sent = 0
	@FocusState private var composing: Bool

	/// Looked up by id and not taken from what's current, so a chat that's fading out keeps its own messages
	private var conversation: AskConversation {
		store.conversation(conversationID) ?? AskConversation(id: conversationID)
	}

	private var run: AskStore.Run? {
		store.runs[conversation.id]
	}

	/// Grows with each piece of the answer that arrives (text, a tool, a button), for a tap per piece
	private var streamed: Int {
		guard let answer = conversation.messages.last, answer.role == .assistant else { return 0 }
		return answer.text.count + answer.tools.count + answer.actions.count
	}

	var body: some View {
		ScrollViewReader { proxy in
			thread
				.overlay {
					if conversation.messages.isEmpty {
						AskEmptyView { draft = $0; composing = true }
					}
				}
				.safeAreaInset(edge: .bottom, spacing: 0) {
					AskComposer(
						text: $draft,
						isFocused: $composing,
						isRunning: run != nil,
						sent: sent,
						send: send,
						stop: { store.stop(conversation.id) }
					)
				}
				.onChange(of: sent) {
					// In a task so the end has moved to below what was just sent
					Task {
						withAnimation(reduceMotion ? nil : .smooth) {
							proxy.scrollTo(Self.end, anchor: .bottom)
						}
					}
				}
		}
		.onChange(of: store.waitingDraft, initial: true) {
			if let waiting = store.takeWaitingDraft() {
				draft = draft.isEmpty ? waiting : "\(draft) \(waiting)"
				composing = true
			}
		}
		.scrollEdgeEffectStyle(.soft, for: .all)
		.sensoryFeedback(.impact(weight: .light), trigger: sent) { _, _ in hapticsEnabled }
		.sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: streamed) { old, new in hapticsEnabled && run != nil && new > old }
		.animation(.smooth, value: run?.activity)
		.animation(.smooth, value: run == nil)
		.animation(.smooth, value: store.failures[conversation.id])
	}

	private var thread: some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 20) {
				ForEach(conversation.messages) { message in
					AskMessageView(message: message, run: message.id == run?.answerID ? run : nil)
						.transition(transition(for: message))
				}

				// Until something arrives for the answer, which then shows this same line in the same place
				if let run, conversation.messages.last?.id != run.answerID {
					AskActivityHeader(word: .for(run.answerID), tools: [], seconds: nil, run: run)
						.transition(.identity)
				}

				if let failure = store.failures[conversation.id] {
					AskFailureRow(message: failure.message, code: failure.code) {
						store.retry(account: account)
					}
				}

				Color.clear
					.frame(height: 0)
					.id(Self.end)
			}
			.padding(.horizontal, 16)
			.padding(.top, 16)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		// Opens on the newest messages, and stays at the end while an answer grows, unless you've scrolled up to read
		.defaultScrollAnchor(.bottom, for: .initialOffset)
		.defaultScrollAnchor(.bottom, for: .sizeChanges)
		.scrollDismissesKeyboard(.interactively)
	}

	private func transition(for message: AskMessage) -> AnyTransition {
		.asymmetric(insertion: message.role == .user ? .askSend : .identity, removal: .opacity)
	}

	private func send() {
		sent += 1
		withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.25)) {
			store.send(draft, account: account)
			draft = ""
		}
	}
}
