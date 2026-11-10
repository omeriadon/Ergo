//
//  AskModes.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ErgoProtocol
import SwiftUI

extension AskMode {
	var name: String {
		switch self {
			case .normal: "Normal"
			case .debate: "Debate"
			case .scout: "Scout"
		}
	}

	var symbol: String {
		switch self {
			case .normal: "bubble.left.and.text.bubble.right"
			case .debate: "person.2.wave.2"
			case .scout: "binoculars"
		}
	}

	var blurb: String {
		switch self {
			case .normal: "Paste an argument or ask a question. Answers cite Ergo's library."
			case .debate: "State something you believe, and it argues the other side and holds you to your reasons."
			case .scout: "Paste a passage, and it looks for fallacies and biases and shows you the words."
		}
	}
}

/// Tapping starts a normal chat, and holding it lists the modes
struct AskNewChatButton: View {
	@Environment(AskStore.self)
	private var store

	var body: some View {
		Menu {
			ForEach(AskMode.allCases, id: \.self) { mode in
				Button(mode.name, systemImage: mode.symbol) {
					store.newConversation(mode: mode)
				}
			}
		} label: {
			Label("New Chat", systemImage: "square.and.pencil")
		} primaryAction: {
			store.newConversation()
		}
		.accessibilityIdentifier("ask.newChat")
	}
}

/// Above the composer in a chat with a mode, to say so and to change it
struct AskModeCapsule: View {
	let mode: AskMode
	let change: (AskMode) -> Void

	var body: some View {
		Menu {
			ForEach(AskMode.allCases, id: \.self) { other in
				Button(other.name, systemImage: other.symbol) {
					change(other)
				}
				.disabled(other == mode)
			}
		} label: {
			Label(mode.name, systemImage: mode.symbol)
				.font(.caption.weight(.semibold))
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
		}
		.glassEffect(.regular.tint(.accent.opacity(0.4)).interactive(), in: Capsule())
		.accessibilityLabel("Chat mode")
		.accessibilityValue(mode.name)
		.accessibilityIdentifier("ask.mode")
	}
}

/// The model asking to change the chat's mode. Nothing changes until the person says so.
struct AskModeRequestCard: View {
	let conversationID: AskConversation.ID
	let message: AskMessage
	let request: AskModeRequest

	@Environment(AskStore.self)
	private var store

	@Environment(TranslationAccount.self)
	private var account

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Label("Switch to \(request.mode.name)?", systemImage: request.mode.symbol)
				.font(.subheadline.weight(.semibold))

			Text(request.reason)
				.font(.subheadline)
				.foregroundStyle(.secondary)

			if let accepted = message.modeAccepted {
				Text(accepted ? "Switched to \(request.mode.name)" : "Stayed as it was")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				buttons
			}
		}
		.padding(14)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
		.accessibilityIdentifier("ask.modeRequest")
	}

	private var buttons: some View {
		HStack(spacing: 8) {
			Button("Switch") {
				answer(true)
			}
			.buttonStyle(.glassProminent)
			.accessibilityIdentifier("ask.modeRequest.accept")

			Button("Not Now") {
				answer(false)
			}
			.buttonStyle(.glass)
			.accessibilityIdentifier("ask.modeRequest.deny")
		}
	}

	private func answer(_ accepted: Bool) {
		store.answerModeRequest(accepted, on: message.id, in: conversationID, account: account)
	}
}

/// What an answer changed on the board, and the way to take it back
struct AskBoardEditsView: View {
	let conversationID: AskConversation.ID
	let message: AskMessage
	let edits: [String]

	@Environment(AskStore.self)
	private var store

	private var isUndone: Bool {
		message.editsUndone == true
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(Array(edits.enumerated()), id: \.offset) { _, edit in
				Label(edit, systemImage: "rectangle.and.pencil.and.ellipsis")
					.font(.footnote)
					.strikethrough(isUndone)
					.foregroundStyle(.secondary)
			}

			if isUndone {
				Text("Undone")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else if store.canUndoEdits(of: message.id) {
				Button("Undo", systemImage: "arrow.uturn.backward") {
					store.undoEdits(of: message.id, in: conversationID)
				}
				.buttonStyle(.glass)
				.accessibilityIdentifier("ask.undoEdits")
			}
		}
		.padding(.top, 2)
	}
}
