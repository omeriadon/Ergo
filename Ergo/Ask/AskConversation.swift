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
	var messages: [AskMessage] = []

	/// An answer the server is writing. It carries on if the app is closed, so this is kept to pick it up again.
	var pending: PendingAnswer?

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

	/// What the model gets: the question, then whatever went with it
	var requestText: String {
		([text] + attachments.map(\.requestText))
			.filter { !$0.isEmpty }
			.joined(separator: "\n\n")
	}
}
