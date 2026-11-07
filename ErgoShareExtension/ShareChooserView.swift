//
//  ShareChooserView.swift
//  ErgoShareExtension
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoShare
import SwiftUI

/// What's being shared, and what to do with it. Nothing is done here: the choice goes in the inbox for the app, which has
/// the account, the boards and the room to read a whole web page.
struct ShareChooserView: View {
	private enum Phase {
		case loading
		case nothing
		case choosing(SharedItem.Content)
		case saved
		case failed(String)
	}

	let load: () async -> SharedItem.Content?
	let openErgo: () async -> Bool
	let finish: () -> Void
	let cancel: () -> Void

	@State private var phase = Phase.loading

	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Ergo")
				.toolbarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						Button(role: .cancel, action: cancel)
					}
				}
		}
		.fontDesign(.rounded)
		.task {
			if let content = await load() {
				phase = .choosing(content)
			} else {
				phase = .nothing
			}
		}
	}

	@ViewBuilder
	private var content: some View {
		switch phase {
			case .loading:
				ProgressView()

			case .nothing:
				ContentUnavailableView(
					"Nothing to Share",
					systemImage: "square.and.arrow.up",
					description: Text("Expected a link or some text.")
				)

			case let .choosing(content):
				choices(for: content)

			case .saved:
				ContentUnavailableView {
					Label("Waiting in Ergo", systemImage: "checkmark.circle")
				} description: {
					Text("Open Ergo to carry on.")
				} actions: {
					Button("Done", action: finish)
						.buttonStyle(.glassProminent)
				}

			case let .failed(message):
				ContentUnavailableView(
					"Couldn't Save",
					systemImage: "xmark.circle",
					description: Text(message)
				)
		}
	}

	private func choices(for content: SharedItem.Content) -> some View {
		List {
			Section {
				SharedContentPreview(content: content)
			}

			Section {
				Button("Add to Chat", systemImage: "bubble.left.and.text.bubble.right") {
					choose(.ask, for: content)
				}

				Button("Break Down", systemImage: "arrow.triangle.branch") {
					choose(.breakDown, for: content)
				}

				Button("Add to Board", systemImage: "flowchart") {
					choose(.board, for: content)
				}
			}
		}
	}

	private func choose(_ action: SharedItem.Action, for content: SharedItem.Content) {
		guard let inbox = SharedItemInbox.shared else {
			phase = .failed("Expected the app group \(SharedItemInbox.appGroup), found none")
			return
		}

		do {
			try inbox.put(SharedItem(content: content, action: action))
		} catch {
			phase = .failed(error.localizedDescription)
			return
		}

		Task {
			if await openErgo() {
				finish()
			} else {
				phase = .saved
			}
		}
	}
}

private struct SharedContentPreview: View {
	let content: SharedItem.Content

	var body: some View {
		switch content {
			case let .text(text):
				Text(text)
					.lineLimit(6)

			case let .link(url, title):
				VStack(alignment: .leading, spacing: 4) {
					if let title {
						Text(title)
							.font(.headline)
							.lineLimit(2)
					}

					Text(url.absoluteString)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
		}
	}
}
