//
//  Bubbles.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import SwiftUI

struct AskMessageView: View {
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
				.glassEffect(.regular.tint(.accentColor), in: RoundedRectangle(cornerRadius: 20))
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
