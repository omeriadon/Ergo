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

	var body: some View {
		content
			.toolbar { toolbar }
	}

	@ViewBuilder
	private var content: some View {
		if account.isSignedInHere {
			AskChatsListView()
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
		if account.isSignedInHere, !store.isChatOpen || !store.current.messages.isEmpty {
			ToolbarItem(placement: .topBarTrailing) {
				AskNewChatButton()
					.buttonStyle(.glassProminent)
			}
		}
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
