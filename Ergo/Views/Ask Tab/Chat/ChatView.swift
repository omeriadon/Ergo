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

	/// Set while the search bar is open
	@State private var find: FindState?

	@State private var attachmentsOf: AskConversation?

	@State private var isConfirmingDelete = false

	var body: some View {
		let id = store.current.id
		ZStack {
			AskConversationView(conversationID: id, find: $find)
				.id(id)
				.transition(.opacity)
		}
		.animation(reduceMotion ? nil : .smooth, value: id)
		.onChange(of: id) { find = nil }
		// The search bar takes the navigation bar's place
		.toolbarHiddenWhileFinding(find != nil)
		.navigationTitle(store.current.title)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .title) {
				Text(store.current.title)
					.font(.caption)
			}
		}
		.toolbar {
			if !store.current.messages.isEmpty {
				ToolbarItem(placement: .topBarTrailing) {
					AskNewChatButton()
				}

				ToolbarSpacer(.fixed, placement: .topBarTrailing)
			}

			ToolbarOverflowMenu {
				Button("Search", systemImage: "magnifyingglass") {
					withAnimation(reduceMotion ? nil : .smooth) {
						find = FindState()
					}
				}
				.disabled(store.current.messages.isEmpty)
				.accessibilityIdentifier("ask.search")

				// A chat with nothing in it isn't saved yet
				if !store.current.messages.isEmpty {
					AskChatActions(
						conversation: store.current,
						showAttachments: { attachmentsOf = store.current },
						delete: { isConfirmingDelete = true }
					)
				}
			}
		}
		.sheet(item: $attachmentsOf) { AskAttachmentsSheet(conversation: $0) }
		.confirmationDialog("Delete this chat?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
			Button("Delete", role: .destructive) {
				store.delete(id)
			}
			.accessibilityIdentifier("ask.delete.confirm")
		} message: {
			Text("This can't be undone")
		}
	}
}

/// A chat with its composer. The Ask tab shows it, and so does a board's Quick AI, so it only ever talks about its own conversation.
struct AskConversationView: View {
	let conversationID: AskConversation.ID

	/// The tab it's on, so only the one on screen takes a follow-up left for the composer
	var tab: AppTab = .ask

	/// Quick AI has no search, so it's left closed there
	var find: Binding<FindState?> = .constant(nil)

	/// Quick AI's composer sits in the corners of its sheet
	var fitsSheet = false

	@Environment(AskStore.self)
	private var store

	@Environment(TranslationAccount.self)
	private var account

	@Environment(NavigationManager.self)
	private var navigation

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

	private var attachments: [AskAttachment] {
		store.attachments[conversationID] ?? []
	}

	private var run: AskStore.Run? {
		store.runs[conversation.id]
	}

	/// Grows with each piece of the answer that arrives (text, a tool, a button), for a tap per piece
	private var streamed: Int {
		guard let answer = conversation.messages.last, answer.role == .assistant else { return 0 }
		return answer.text.count + answer.tools.count + answer.actions.count
	}

	/// Newest first, since a chat opens at its end
	private var findMatches: [AskMessage.ID] {
		guard let query = find.wrappedValue?.query, !query.isEmpty else { return [] }
		return conversation.messages.reversed()
			.filter { $0.text.matchesFind(query) }
			.map(\.id)
	}

	private var currentFindMatch: AskMessage.ID? {
		find.wrappedValue?.current(in: findMatches)
	}

	var body: some View {
		ScrollViewReader { proxy in
			thread
				.overlay {
					if conversation.messages.isEmpty {
						AskEmptyView(mode: conversation.mode ?? .normal, isAboutBoard: conversation.board != nil) { draft = $0; composing = true }
					}
				}
				.safeAreaBar(edge: .bottom, spacing: 0) {
					composer
				}
				.safeAreaBar(edge: .top, spacing: 0) {
					findBar
				}
				.onChange(of: currentFindMatch) {
					if let currentFindMatch {
						withAnimation(reduceMotion ? nil : .smooth) {
							proxy.scrollTo(currentFindMatch, anchor: .center)
						}
					}
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
			if navigation.selectedTab == tab, let waiting = store.takeWaitingDraft() {
				draft = draft.isEmpty ? waiting : "\(draft) \(waiting)"
				composing = true
			}
		}
		.onChange(of: draft, takePaste)
		.scrollEdgeEffectStyle(.soft, for: .all)
		.sensoryFeedback(.impact(weight: .light), trigger: sent) { _, _ in hapticsEnabled }
		.sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: streamed) { old, new in hapticsEnabled && run != nil && new > old }
		.animation(.smooth, value: run?.activity)
		.animation(.smooth, value: run == nil)
		.animation(.smooth, value: store.failures[conversation.id])
	}

	@ViewBuilder
	private var findBar: some View {
		if find.wrappedValue != nil {
			FindBar(find: find, prompt: "Search this chat", count: findMatches.count, isNewestFirst: true)
				.transition(.move(edge: .top).combined(with: .opacity))
		}
	}

	private var composer: some View {
		VStack(spacing: 0) {
			if let mode = conversation.mode, mode != .normal {
				AskModeCapsule(mode: mode) { store.setMode($0, for: conversationID) }
					.padding(.top, 6)
					.transition(.blurReplace)
			}

			if !attachments.isEmpty {
				AskAttachmentsRow(
					attachments: attachments,
					remove: { store.removeAttachment($0, from: conversationID) },
					update: { store.updateAttachment($0, in: conversationID, text: $1) }
				)
				.contentMargins(.horizontal, fitsSheet ? AskComposer.sheetInset : 22, for: .scrollContent)
				.transition(.blurReplace)
			}

			AskComposer(
				text: $draft,
				isFocused: $composing,
				hasAttachments: !attachments.isEmpty,
				isRunning: run != nil,
				sent: sent,
				fitsSheet: fitsSheet,
				send: send,
				stop: { store.stop(conversation.id) }
			)
		}
		.animation(reduceMotion ? nil : .smooth, value: attachments)
		.animation(reduceMotion ? nil : .smooth, value: conversation.mode)
	}

	private var thread: some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 20) {
				ForEach(conversation.messages) { message in
					AskMessageView(conversationID: conversationID, message: message, run: message.id == run?.answerID ? run : nil)
						.transition(transition(for: message))
				}

				// Until something arrives for the answer, which then shows this same line in the same place
				if let run, conversation.messages.last?.id != run.answerID {
					AskActivityHeader(word: .for(run.answerID), tools: [], seconds: nil, run: run)
						.transition(.identity)
				}

				if let failure = store.failures[conversation.id] {
					AskFailureRow(message: failure.message, code: failure.code) {
						store.retry(conversationID, account: account)
					}
				}

				Color.clear
					.frame(height: 0)
					.id(Self.end)
			}
			.padding(.horizontal, 16)
			.padding(.top, 16)
			.frame(maxWidth: .infinity, alignment: .leading)
			.environment(\.findHighlight, find.wrappedValue?.query)
		}
		// Opens on the newest messages, and stays at the end while an answer grows, unless you've scrolled up to read
		.defaultScrollAnchor(.bottom, for: .initialOffset)
		.defaultScrollAnchor(.bottom, for: .sizeChanges)
		.scrollDismissesKeyboard(.interactively)
	}

	private func transition(for message: AskMessage) -> AnyTransition {
		unsafe .asymmetric(insertion: message.role == .user ? .askSend : .identity, removal: .opacity)
	}

	/// Typing only adds a little at a time, so this much arriving at once is a paste
	private func takePaste(from old: String, to new: String) {
		let start = zip(old, new).prefix { $0 == $1 }.count
		let end = zip(old.dropFirst(start).reversed(), new.dropFirst(start).reversed()).prefix { $0 == $1 }.count
		let pasted = new.dropFirst(start).dropLast(end)
		guard pasted.split(whereSeparator: \.isWhitespace).count > AskAttachment.pasteWordLimit else { return }

		draft = String(new.prefix(start)) + String(new.suffix(end))
		store.attach(.text(pasted.trimmingCharacters(in: .whitespacesAndNewlines)), to: conversationID)
	}

	private func send() {
		sent += 1
		withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.25)) {
			store.send(draft, in: conversationID, account: account)
			draft = ""
		}
	}
}
