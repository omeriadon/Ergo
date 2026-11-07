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
struct AskConversation: Codable, Hashable, Identifiable, Defaults.Serializable {
	var id = UUID()
	var created = Date.now
	var modified = Date.now

	/// Given by the person. Empty means it's titled from the first question.
	var name = ""
	var messages: [AskMessage] = []

	/// Its name, else the first thing asked
	var title: String {
		if let name = name.trimmedNonEmpty {
			return name
		}
		let line = messages.first { $0.role == .user }?.text
			.split(whereSeparator: \.isNewline)
			.first
			.map { $0.trimmingCharacters(in: .whitespaces) }
		return line ?? "New Chat"
	}
}

struct AskMessage: Codable, Hashable, Identifiable {
	var id = UUID()
	var role: AskRequestMessage.Role
	var text: String

	/// What it looked up for an answer, worded for showing above it
	var tools: [String] = []

	/// How long an answer took, once it's finished
	var seconds: Int?

	/// Buttons under an answer
	var actions: [AskAction] = []
}
