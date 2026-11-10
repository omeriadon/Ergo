//
//  QuickAISheet.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ErgoProtocol
import SwiftUI

/// A chat beside the canvas that sees the board and can change it. It's an ordinary chat, so it's in the Ask tab's list too.
struct QuickAISheet: View {
	let board: Board.ID

	@Environment(AskStore.self)
	private var store

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(TranslationAccount.self)
	private var account

	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Quick AI")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar { toolbar }
		}
		.presentationDetents([.medium, .large])
		// The board stays usable behind it at half height
		.presentationBackgroundInteraction(.enabled(upThrough: .medium))
		.presentationDragIndicator(.visible)
		.task(id: board) {
			store.openBoardChat(board)
		}
		// Deleted on another device, or this sheet was restored after that happened
		.onChange(of: boardStore.board(board) == nil, initial: true) {
			if boardStore.board(board) == nil {
				navigation.dismissSheet()
			}
		}
	}

	@ViewBuilder
	private var content: some View {
		if !account.isSignedInHere {
			ContentUnavailableView {
				Label("Sign In to Ask", systemImage: "sparkles")
			} description: {
				Text("Quick AI runs through your Ergo account.")
			} actions: {
				Button("Open Settings") {
					navigation.presentSheet(.settings(id: "3refd"))
				}
				.buttonStyle(.glassProminent)
				.accessibilityIdentifier("quickAI.signIn")
			}
		} else if store.current.board == board {
			AskConversationView(conversationID: store.current.id, tab: .board)
				.id(store.current.id)
		}
	}

	@ToolbarContentBuilder
	private var toolbar: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			Button(role: .close) {
				navigation.dismissSheet()
			}
			.accessibilityIdentifier("quickAI.close")
		}

		ToolbarItem(placement: .topBarTrailing) {
			Button("New Chat", systemImage: "square.and.pencil") {
				store.newBoardChat(board)
			}
			.disabled(store.current.board != board || store.current.messages.isEmpty)
			.accessibilityIdentifier("quickAI.newChat")
		}
	}
}
