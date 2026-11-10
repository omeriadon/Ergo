//
//  Bubbles.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import SwiftUI

struct AskMessageView: View {
	let conversationID: AskConversation.ID
	let message: AskMessage

	/// Set while this is the answer being written
	let run: AskStore.Run?

	var body: some View {
		switch message.role {
			case .user:
				AskUserBubble(text: message.text, attachments: message.attachments)
			case .assistant:
				AskAnswerView(conversationID: conversationID, message: message, run: run)
		}
	}
}

private struct AskUserBubble: View {
	let text: String
	let attachments: [AskAttachment]

	@Environment(\.findHighlight)
	private var findHighlight

	var body: some View {
		VStack(spacing: 8) {
			if !attachments.isEmpty {
				AskAttachmentsRow(attachments: attachments)
					.defaultScrollAnchor(.trailing)
			}

			if !text.isEmpty {
				bubble
			}
		}
	}

	private var bubble: some View {
		HStack {
			Spacer(minLength: 48)

			Text(AttributedString(text).findHighlighted(findHighlight))
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
				.glassEffect(.clear.tint(.accent).interactive(), in: RoundedRectangle(cornerRadius: 20))
				.contextMenu {
					Button("Copy", systemImage: "doc.on.doc") {
						UIPasteboard.general.string = text
					}
				}
		}
	}
}

private struct AskAnswerView: View {
	let conversationID: AskConversation.ID
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

			if let edits = message.edits, !edits.isEmpty {
				AskBoardEditsView(conversationID: conversationID, message: message, edits: edits)
			}

			if run == nil, let request = message.modeRequest {
				AskModeRequestCard(conversationID: conversationID, message: message, request: request)
			}

			GlassEffectContainer(spacing: 1) {
				FlowLayout(spacing: 8) {
					ForEach(actions, id: \.self) { action in
						var isAskFollowUp: Bool {
							if case .askFollowUp = action.intent {
								true
							} else {
								false
							}
						}

						Button(action.title) {
							AskIntents.run(action.intent, navigation: navigation, store: store)
						}
						.buttonStyle(.glass(.regular.tint(isAskFollowUp ? .black.opacity(0.2) : .accent.opacity(0.6)).interactive()))
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
}

struct FlowLayout: Layout {
	var spacing: CGFloat = 8

	func sizeThatFits(
		proposal: ProposedViewSize,
		subviews: Subviews,
		cache _: inout ()
	) -> CGSize {
		let width = proposal.width ?? .infinity
		var x: CGFloat = 0
		var y: CGFloat = 0
		var rowHeight: CGFloat = 0

		for subview in subviews {
			let size = subview.sizeThatFits(.unspecified)

			if x + size.width > width, x > 0 {
				x = 0
				y += rowHeight + spacing
				rowHeight = 0
			}

			x += size.width + spacing
			rowHeight = max(rowHeight, size.height)
		}

		return CGSize(
			width: width,
			height: y + rowHeight
		)
	}

	func placeSubviews(
		in bounds: CGRect,
		proposal _: ProposedViewSize,
		subviews: Subviews,
		cache _: inout ()
	) {
		var x = bounds.minX
		var y = bounds.minY
		var rowHeight: CGFloat = 0

		for subview in subviews {
			let size = subview.sizeThatFits(.unspecified)

			if x + size.width > bounds.maxX, x > bounds.minX {
				x = bounds.minX
				y += rowHeight + spacing
				rowHeight = 0
			}

			subview.place(
				at: CGPoint(x: x, y: y),
				proposal: ProposedViewSize(size)
			)

			x += size.width + spacing
			rowHeight = max(rowHeight, size.height)
		}
	}
}
