//
//  ChatView.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import Defaults
import ErgoProtocol
import SwiftUI

struct AskThreadView: View {
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

	private var conversation: AskConversation {
		store.current
	}

	private var run: AskStore.Run? {
		store.runs[conversation.id]
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
		.toolbarTitleVire(conversation.title, "")
		.sensoryFeedback(.impact(weight: .light), trigger: sent) { _, _ in hapticsEnabled }
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
