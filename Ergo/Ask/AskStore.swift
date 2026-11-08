//
//  AskStore.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoProtocol
import SwiftUI

/// Every conversation, and which one the Ask tab is showing. Answers are kept here and not on a view, so one carries on
/// while you're on another tab or another conversation, and only the stop button ends it.
@MainActor
@Observable
final class AskStore {
	/// Where an answer that's being written has got to
	struct Run {
		let task: Task<Void, Never>

		/// The message it's writing, which doesn't exist until something arrives for it
		let answerID: AskMessage.ID
		let started: Date

		/// What its tools are doing, while it isn't writing
		var activity: String?
	}

	// MARK: - conversations

	private(set) var conversations: [AskConversation]

	/// Newest first
	var sortedConversations: [AskConversation] {
		conversations.sorted { $0.modified > $1.modified }
	}

	private(set) var currentID: AskConversation.ID? {
		didSet {
			Defaults[.currentAskConversationID] = currentID
		}
	}

	/// Whether the Ask tab has a chat open, as opposed to showing the list
	private(set) var isChatOpen: Bool

	/// Stays out of the list until something's been asked
	private var draft = AskConversation()

	var current: AskConversation {
		conversations.first { $0.id == currentID } ?? draft
	}

	private(set) var runs: [AskConversation.ID: Run] = [:]

	/// Why the last answer failed, until it's tried again
	private(set) var failures: [AskConversation.ID: ServiceError] = [:]

	/// Text from the share sheet, until the composer takes it. It isn't sent, so the person can say what to ask about it.
	private(set) var waitingDraft: String?

	/// What's going with each chat's next message. Not saved, like what's typed in the composer.
	private(set) var attachments: [AskConversation.ID: [AskAttachment]] = [:]

	init() {
		conversations = Defaults[.askConversations]
		let id = Defaults[.currentAskConversationID]
		currentID = id
		isChatOpen = id != nil
	}

	/// Opens an empty chat. One that's already empty and open is left as it is, with whatever's been typed in it.
	func newConversation() {
		if !current.messages.isEmpty {
			draft = AskConversation()
			currentID = nil
		}
		isChatOpen = true
	}

	func open(_ id: AskConversation.ID) {
		currentID = id
		isChatOpen = true
	}

	/// Back to the list. The chat stays current for now, so it doesn't change while the screen slides away, but isn't reopened on launch.
	func closeChat() {
		isChatOpen = false
		Defaults[.currentAskConversationID] = nil
	}

	/// A chat that's still empty takes it too, so a few things can be gathered up before asking
	func startChat(attaching content: AskAttachment.Content) {
		newConversation()
		guard attachments[current.id]?.contains(where: { $0.content == content }) != true else { return }
		attachments[current.id, default: []].append(AskAttachment(content: content))
	}

	func removeAttachment(_ id: AskAttachment.ID, from conversation: AskConversation.ID) {
		attachments[conversation]?.removeAll { $0.id == id }
	}

	func updateAttachment(_ id: AskAttachment.ID, in conversation: AskConversation.ID, text: String) {
		guard let index = attachments[conversation]?.firstIndex(where: { $0.id == id }) else { return }
		attachments[conversation]?[index].content = .text(text)
	}

	/// Leaves a question in the composer of the conversation that's open, to edit or send
	func draftFollowUp(_ text: String) {
		waitingDraft = text
	}

	func takeWaitingDraft() -> String? {
		defer { waitingDraft = nil }
		return waitingDraft
	}

	func delete(_ id: AskConversation.ID) {
		stop(id)
		conversations.removeAll { $0.id == id }
		failures[id] = nil
		attachments[id] = nil
		if currentID == id {
			draft = AskConversation()
			currentID = nil
		}
		save()
	}

	/// An empty name goes back to titling the chat from the first question
	func rename(_ id: AskConversation.ID, to name: String) {
		guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
		conversations[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
		save()
	}

	// MARK: - asking

	func send(_ text: String, account: TranslationAccount) {
		let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
		let attached = attachments[current.id] ?? []
		guard !text.isEmpty || !attached.isEmpty, runs[current.id] == nil else { return }

		var conversation = current
		conversation.messages.append(AskMessage(role: .user, text: text, attachments: attached))
		attachments[conversation.id] = nil
		write(conversation)
		answer(conversation.id, account: account)
	}

	/// Asks the last question again after a failure, without whatever part of an answer it got to
	func retry(account: TranslationAccount) {
		var conversation = current
		if conversation.messages.last?.role == .assistant {
			conversation.messages.removeLast()
			write(conversation)
		}
		guard conversation.messages.last?.role == .user else { return }
		answer(conversation.id, account: account)
	}

	/// Keeps what's been written so far. Closing the socket makes the server stop too.
	func stop(_ id: AskConversation.ID) {
		runs[id]?.task.cancel()
		end(id)
		save()
	}

	/// Notes how long the answer took, for the line above it
	private func end(_ id: AskConversation.ID) {
		guard let run = runs.removeValue(forKey: id),
		      var conversation = conversation(id),
		      let index = conversation.messages.firstIndex(where: { $0.id == run.answerID })
		else { return }
		conversation.messages[index].seconds = Int(Date.now.timeIntervalSince(run.started).rounded())
		write(conversation)
	}

	private func answer(_ id: AskConversation.ID, account: TranslationAccount) {
		failures[id] = nil
		let messages = Self.request(from: conversation(id)?.messages ?? [])
		// One message for the whole answer, added to as it arrives
		let answerID = UUID()

		let task = Task {
			do {
				try await account.ask(messages: messages) { event in
					guard !Task.isCancelled else { return }
					apply(event, to: answerID, in: id)
				}
				guard !Task.isCancelled else { return }
				end(id)
				save()
			} catch {
				guard !Task.isCancelled, !(error is CancellationError) else { return }
				end(id)
				failures[id] = error as? ServiceError
					?? ServiceError(code: .internalError, message: error.localizedDescription)
				save()
			}
		}
		runs[id] = Run(task: task, answerID: answerID, started: .now)
	}

	private func apply(_ event: AskServerMessage, to answerID: AskMessage.ID, in id: AskConversation.ID) {
		guard var conversation = conversation(id) else { return }
		func updateAnswer(_ update: (inout AskMessage) -> Void) {
			if let index = conversation.messages.firstIndex(where: { $0.id == answerID }) {
				update(&conversation.messages[index])
			} else {
				var answer = AskMessage(id: answerID, role: .assistant, text: "")
				update(&answer)
				conversation.messages.append(answer)
			}
			write(conversation)
		}

		switch event {
			case let .text(text):
				runs[id]?.activity = nil
				updateAnswer { $0.text += text }

			case let .tool(activity):
				runs[id]?.activity = activity.summary
				updateAnswer { answer in
					if !answer.tools.contains(activity.record) {
						answer.tools.append(activity.record)
					}
				}

			case let .action(action):
				updateAnswer { answer in
					if !answer.actions.contains(action) {
						answer.actions.append(action)
					}
				}

			case .finished, .failed, .unknown:
				break
		}
	}

	/// The newest messages that fit, since the server turns away what's longer. A cut can't start on an answer.
	static func request(from messages: [AskMessage]) -> [AskRequestMessage] {
		var kept: [AskRequestMessage] = []
		var characters = 0
		for message in messages.reversed() where !message.requestText.isEmpty {
			let text = message.requestText
			characters += text.count
			guard characters <= AskRequest.characterLimit else { break }
			kept.insert(AskRequestMessage(role: message.role, text: text), at: 0)
		}
		if kept.first?.role == .assistant {
			kept.removeFirst()
		}
		return kept
	}

	// MARK: - storing

	func conversation(_ id: AskConversation.ID) -> AskConversation? {
		conversations.first { $0.id == id } ?? (draft.id == id ? draft : nil)
	}

	private func write(_ conversation: AskConversation) {
		var conversation = conversation
		conversation.modified = .now

		if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
			conversations[index] = conversation
		} else {
			conversations.append(conversation)
			currentID = conversation.id
		}
	}

	/// Not on every word of an answer, only when one ends
	func save() {
		Defaults[.askConversations] = conversations
	}
}
