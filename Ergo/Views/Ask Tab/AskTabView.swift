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

	/// Set while this is the answer being written
	let run: AskStore.Run?

	var body: some View {
		switch message.role {
			case .user:
				AskUserBubble(text: message.text)
			case .assistant:
				AskAnswerView(message: message, run: run)
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

	/// Set while it's being written
	let run: AskStore.Run?

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(AskStore.self)
	private var store

	/// They wait for the end, so they don't push the answer around while it's being read
	private var actions: [AskAction] {
		run == nil ? message.actions.filter { AskIntents.canRun($0.intent) } : []
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			AskActivityHeader(word: .for(message.id), tools: message.tools, seconds: message.seconds, run: run)

			AskMarkdownView(text: message.text)

			if run == nil, !message.text.isEmpty {
				AskCopyButton(text: message.text)
					.padding(.top, 2)
			}

			if !actions.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					ForEach(actions, id: \.self) { action in
						Button(action.title) {
							AskIntents.run(action.intent, navigation: navigation, store: store)
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
			AskIntents.run(intent, navigation: navigation, store: store)
			return .handled
		})
	}
}

/// One line above an answer, "Contemplated for 12 seconds", that opens to show what it did on the way
private struct AskActivityHeader: View {
	let word: AskThinkingWord
	let tools: [String]
	let seconds: Int?

	/// Set while it's being written
	let run: AskStore.Run?

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@State private var isExpanded = false

	/// Having looked up nothing is worth saying too, since answers are meant to come from the library
	private var items: [String] {
		tools.isEmpty && run == nil ? ["Didn't check the library"] : tools
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Button {
				withAnimation(.smooth) {
					isExpanded.toggle()
				}
			} label: {
				header
			}
			.buttonStyle(.plain)
			.disabled(items.isEmpty)
			.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
			.accessibilityIdentifier("ask.activity")

			if isExpanded {
				ForEach(Array(items.enumerated()), id: \.element) { index, item in
					Text(item)
						.font(.caption)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
						.transition(itemTransition(at: index))
						.accessibilityIdentifier("ask.tools")
				}
			}
		}
	}

	private var header: some View {
		HStack(spacing: 5) {
			if run != nil {
				ProgressView()
					.controlSize(.mini)
			}

			TimelineView(.animation(minimumInterval: 1, paused: run == nil)) { context in
				let title = title(at: context.date)
				Text(title)
					.lineLimit(1)
					.contentTransition(.numericText())
					.animation(.smooth, value: title)
			}

			if !items.isEmpty {
				Image(systemName: "chevron.right")
					.font(.caption2.weight(.semibold))
					.rotationEffect(.degrees(isExpanded ? 90 : 0))
					.transition(.opacity)
			}
		}
		.font(.caption)
		.foregroundStyle(.tertiary)
		.contentShape(Rectangle())
	}

	/// What its tools are doing right now says more than how long it's been
	private func title(at date: Date) -> String {
		guard let run else {
			return seconds.map { "\(word.past) for \(Self.spelledOut($0))" } ?? word.past
		}
		return run.activity ?? "\(word.gerund) for \(Self.spelledOut(Int(date.timeIntervalSince(run.started))))"
	}

	private static func spelledOut(_ seconds: Int) -> String {
		Duration.seconds(max(seconds, 1)).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
	}

	/// Each one a beat after the last, falling out of the header
	private func itemTransition(at index: Int) -> AnyTransition {
		guard !reduceMotion else { return .opacity }
		return AnyTransition.opacity
			.combined(with: .offset(y: -6))
			.animation(.smooth.delay(Double(index) * 0.03))
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
