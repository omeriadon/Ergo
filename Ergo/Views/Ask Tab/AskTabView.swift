//
//  AskTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoProtocol
import SwiftUI

/// The Ask tab: a chat with the user's own model, grounded in the library. It needs an account, since it runs on the server.
struct AskTabView: View {
	@Environment(AskStore.self)
	private var store

	@Environment(TranslationAccount.self)
	private var account

	@Environment(NavigationManager.self)
	private var navigation

	@State private var showingHistory = false

	var body: some View {
		content
			.toolbar { toolbar }
			.sheet(isPresented: $showingHistory) {
				AskHistorySheet()
			}
	}

	@ViewBuilder
	private var content: some View {
		if account.isSignedInHere {
			AskThreadView()
				.id(store.current.id)
		} else {
			ContentUnavailableView {
				Label("Sign In to Ask", systemImage: "bubble.left.and.text.bubble.right")
			} description: {
				Text("Ask runs on your own Claude or ChatGPT login, through your Ergo account.")
			} actions: {
				Button("Open Settings") {
					navigation.presentSheet(.settings(id: "3refd"))
				}
				.buttonStyle(.glassProminent)
				.accessibilityIdentifier("ask.signIn")
			}
		}
	}

	@ToolbarContentBuilder
	private var toolbar: some ToolbarContent {
		if account.isSignedInHere {
			ToolbarItem(placement: .topBarLeading) {
				Button("History", systemImage: "clock.arrow.circlepath") {
					showingHistory = true
				}
				.accessibilityIdentifier("ask.history")
			}

			ToolbarItem(placement: .topBarTrailing) {
				Button("New Chat", systemImage: "square.and.pencil") {
					store.newConversation()
				}
				.disabled(store.current.messages.isEmpty)
				.accessibilityIdentifier("ask.newChat")
			}
		}
	}
}

// MARK: - Thread

/// One conversation and the box to write in. An answer keeps going if this goes away, since `AskStore` owns it.
private struct AskThreadView: View {
	@Environment(AskStore.self)
	private var store

	@Environment(TranslationAccount.self)
	private var account

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@Default(.hapticsEnabled) private var hapticsEnabled

	@State private var draft = ""
	@State private var position = ScrollPosition(edge: .bottom)

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
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 20) {
				ForEach(conversation.messages) { message in
					AskMessageView(message: message, isAnswering: run != nil && message.id == conversation.messages.last?.id)
						.transition(.asymmetric(insertion: .askSend, removal: .opacity))
				}

				if let run, isWaiting(for: run) {
					AskActivityRow(activity: run.activity)
				}

				if let failure = store.failures[conversation.id] {
					AskFailureRow(message: failure.message, code: failure.code) {
						store.retry(account: account)
					}
				}
			}
			.padding(16)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.scrollPosition($position)
		// Stays at the end while an answer grows, unless you've scrolled up to read
		.defaultScrollAnchor(.bottom, for: .sizeChanges)
		.scrollDismissesKeyboard(.interactively)
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
		.sensoryFeedback(.impact(weight: .light), trigger: sent) { _, _ in hapticsEnabled }
		.animation(.smooth, value: run?.activity)
		.animation(.smooth, value: store.failures[conversation.id])
	}

	/// Nothing's being written yet, or it's gone off to look something up
	private func isWaiting(for run: AskStore.Run) -> Bool {
		guard let last = conversation.messages.last, last.role == .assistant, !last.text.isEmpty else { return true }
		return run.activity != nil
	}

	private func send() {
		sent += 1
		withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.25)) {
			store.send(draft, account: account)
			draft = ""
			position.scrollTo(edge: .bottom)
		}
	}
}

private extension AnyTransition {
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

// MARK: - Messages

private struct AskMessageView: View {
	let message: AskMessage
	let isAnswering: Bool

	var body: some View {
		switch message.role {
			case .user:
				AskUserBubble(text: message.text)
			case .assistant:
				AskAnswerView(message: message, isAnswering: isAnswering)
		}
	}
}

private struct AskUserBubble: View {
	let text: String

	var body: some View {
		HStack {
			Spacer(minLength: 48)

			Text(text)
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
				.glassEffect(.regular.tint(.accentColor.opacity(0.25)), in: RoundedRectangle(cornerRadius: 20))
				.contextMenu {
					Button("Copy", systemImage: "doc.on.doc") {
						UIPasteboard.general.string = text
					}
				}
		}
	}
}

private struct AskAnswerView: View {
	let message: AskMessage
	let isAnswering: Bool

	@Environment(NavigationManager.self)
	private var navigation

	private var actions: [AskAction] {
		message.actions.filter { AskIntents.canRun($0.intent) }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			AskToolsCaption(tools: message.tools, isAnswering: isAnswering)

			AskMarkdownView(text: message.text)

			if !isAnswering, !message.text.isEmpty {
				AskCopyButton(text: message.text)
					.padding(.top, 2)
			}

			if !actions.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					ForEach(actions, id: \.self) { action in
						Button(action.title) {
							AskIntents.run(action.intent, navigation: navigation)
						}
						.buttonStyle(.glass)
					}
				}
				.padding(.top, 4)
			}
		}
		.environment(\.openURL, OpenURLAction { url in
			// A library link is one of the app's intents. Anything else goes wherever a link goes.
			guard let intent = AskIntent(url: url) else {
				return .systemAction
			}
			AskIntents.run(intent, navigation: navigation)
			return .handled
		})
	}
}

/// What it looked up for this answer. Having looked up nothing is worth saying too, since answers are meant to come from
/// the library.
private struct AskToolsCaption: View {
	let tools: [String]
	let isAnswering: Bool

	private var caption: String? {
		if !tools.isEmpty {
			return tools.joined(separator: " · ")
		}
		return isAnswering ? nil : "Didn't check the library"
	}

	var body: some View {
		if let caption {
			Text(caption)
				.font(.caption)
				.foregroundStyle(.tertiary)
				.fixedSize(horizontal: false, vertical: true)
				.contentTransition(.opacity)
				.animation(.smooth, value: caption)
				.accessibilityIdentifier("ask.tools")
		}
	}
}

private struct AskActivityRow: View {
	/// What its tools are doing, nil while it's only thinking
	let activity: String?

	var body: some View {
		HStack(spacing: 8) {
			ProgressView()
				.controlSize(.small)

			Text(activity ?? "Thinking")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.contentTransition(.opacity)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier("ask.activity")
	}
}

private struct AskFailureRow: View {
	let message: String
	let code: ServiceError.Code
	let retry: () -> Void

	@Environment(NavigationManager.self)
	private var navigation

	/// Only for errors fixed by connecting a provider in Settings
	private var needsSetUp: Bool {
		code == .notConnected || code == .credentialRejected
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Label(message, systemImage: "xmark.circle.fill")
				.font(.subheadline)
				.foregroundStyle(.red)

			if needsSetUp {
				Button("Set Up") {
					navigation.presentSheet(.settings(id: "3refd"))
				}
				.buttonStyle(.glass)
			} else {
				Button("Try Again", systemImage: "arrow.clockwise", action: retry)
					.buttonStyle(.glass)
			}
		}
		.accessibilityIdentifier("ask.failure")
	}
}

// MARK: - Empty

private struct AskEmptyView: View {
	private static let starters = [
		"Is there a fallacy in this argument?",
		"What's the difference between valid and sound?",
		"Which biases affect how we judge evidence?",
	]

	let pick: (String) -> Void

	var body: some View {
		VStack(spacing: 20) {
			ContentUnavailableView(
				"Ask",
				systemImage: "bubble.left.and.text.bubble.right",
				description: Text("Paste an argument or ask a question. Answers cite Ergo's library.")
			)
			.fixedSize(horizontal: false, vertical: true)

			VStack(spacing: 8) {
				ForEach(Self.starters, id: \.self) { starter in
					Button(starter) {
						pick(starter)
					}
					.buttonStyle(.glass)
				}
			}
		}
		.padding(16)
	}
}

// MARK: - Composer

private struct AskComposer: View {
	@Binding var text: String
	var isFocused: FocusState<Bool>.Binding
	let isRunning: Bool
	let sent: Int
	let send: () -> Void
	let stop: () -> Void

	private var canSend: Bool {
		!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		HStack(alignment: .bottom, spacing: 8) {
			TextField("Ask anything", text: $text, axis: .vertical)
				.lineLimit(1 ... 6)
				.focused(isFocused)
				.padding(.horizontal, 16)
				.padding(.vertical, 11)
				.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22))
				.accessibilityIdentifier("ask.composer")

			if isRunning {
				Button("Stop", systemImage: "stop.fill", action: stop)
					.labelStyle(.iconOnly)
					.buttonStyle(.glass)
					.buttonBorderShape(.circle)
					.controlSize(.large)
					.accessibilityIdentifier("ask.stop")
			} else {
				Button("Send", systemImage: "arrow.up", action: send)
					.labelStyle(.iconOnly)
					.symbolEffect(.bounce.up, value: sent)
					.buttonStyle(.glassProminent)
					.buttonBorderShape(.circle)
					.controlSize(.large)
					.disabled(!canSend)
					.accessibilityIdentifier("ask.send")
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.animation(.smooth, value: isRunning)
	}
}

// MARK: - History

private struct AskHistorySheet: View {
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

#Preview {
	NavigationStack {
		AskTabView()
	}
	.environment(AskStore())
	.environment(TranslationAccount())
	.environment(NavigationManager())
	.environment(CatalogStore())
}
