//
//  AskConversation.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoProtocol
import Foundation

/// One chat on the Ask tab
nonisolated struct AskConversation: Codable, Hashable, Identifiable, Defaults.Serializable {
	var id = UUID()
	var created = Date.now
	var modified = Date.now

	/// Given by the person. Empty means it's titled from the first question.
	var name = ""

	/// Named by the server once its first answer is done. A name the person gives wins over it.
	var suggestedTitle: String?
	var messages: [AskMessage] = []

	/// An answer the server is writing. It carries on if the app is closed, so this is kept to pick it up again.
	var pending: PendingAnswer?

	// Everything below is optional so chats saved before it existed still read

	/// Nil is the normal mode
	var mode: AskMode?

	/// The board this chat is about. The model sees it with every question, and can change it.
	var board: Board.ID?

	/// The changes the model has already made to the board, so hearing an answer again doesn't make them twice
	var appliedEdits: [UUID]?

	/// Which run on the server is writing an answer, and where the answer goes
	struct PendingAnswer: Codable, Hashable {
		/// The run's name on the server. Asking again with it hears the same answer.
		var run: UUID

		/// The message it writes into, which doesn't exist until something arrives for it
		var answer: AskMessage.ID
		var started: Date
	}

	/// Its name, else the first thing asked
	var title: String {
		if let name = name.trimmedNonEmpty {
			return name
		}
		if let suggestedTitle = suggestedTitle?.trimmedNonEmpty {
			return suggestedTitle
		}
		let question = messages.first { $0.role == .user }
		let line = question?.text
			.split(whereSeparator: \.isNewline)
			.first
			.map { $0.trimmingCharacters(in: .whitespaces) }
		return line ?? question?.attachments.first?.title ?? "New Chat"
	}
}

nonisolated struct AskMessage: Codable, Hashable, Identifiable, Sendable {
	var id = UUID()
	var role: AskRequestMessage.Role
	var text: String

	/// What went along with a question
	var attachments: [AskAttachment] = []

	/// What it looked up for an answer, worded for showing above it
	var tools: [String] = []

	/// How long an answer took, once it's finished
	var seconds: Int?

	/// Buttons under an answer
	var actions: [AskAction] = []

	/// The model asking to change the chat's mode
	var modeRequest: AskModeRequest?

	/// Whether the person took it up, nil until they've said
	var modeAccepted: Bool?

	/// What the answer changed on the board, a line for each
	var edits: [String]?

	/// The changes were taken back
	var editsUndone: Bool?

	/// What the model gets: the question, then whatever went with it
	var requestText: String {
		([text] + attachments.map(\.requestText))
			.filter { !$0.isEmpty }
			.joined(separator: "\n\n")
	}
}
