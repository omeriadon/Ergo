//
//  SharedItemSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import ErgoShare
import SwiftUI

/// Picks up what came in through the share sheet: reads the page when it's a link, then carries on with what was chosen in
/// the extension. Text for a chat doesn't come here, since there's nothing to wait for (`ErgoApp`).
struct SharedItemSheet: View {
	private enum Phase {
		case reading
		case failed(String)
		case ready(String)
	}

	let item: SharedItem

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(AskStore.self)
	private var askStore

	@State private var phase: Phase
	@State private var attempt = 0

	init(item: SharedItem) {
		self.item = item
		if case let .text(text) = item.content {
			_phase = State(initialValue: .ready(text))
		} else {
			_phase = State(initialValue: .reading)
		}
	}

	var body: some View {
		content
			.task(id: attempt) {
				if case .ready = phase {
					return
				}
				await read()
			}
	}

	@ViewBuilder
	private var content: some View {
		switch phase {
			case .reading:
				waiting {
					ProgressView("Reading Page")
				}

			case let .failed(message):
				waiting {
					ContentUnavailableView {
						Label("Couldn't Read Page", systemImage: "exclamationmark.triangle")
					} description: {
						Text(message)
					} actions: {
						Button("Try Again", systemImage: "arrow.clockwise") {
							phase = .reading
							attempt += 1
						}
						.buttonStyle(.glass)
						.accessibilityIdentifier("share.tryAgain")
					}
				}

			case let .ready(text):
				switch item.action {
					case .breakDown:
						BreakDownSheet(shared: text)
					case .board:
						AddToBoardSheet(english: text)
					case .ask:
						// Already gone to the chat, and this sheet with it
						EmptyView()
				}
		}
	}

	private func waiting(@ViewBuilder _ content: () -> some View) -> some View {
		NavigationStack {
			content()
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						Button(role: .cancel) {
							navigation.dismissSheet()
						}
						.accessibilityIdentifier("share.cancel")
					}
				}
		}
	}

	// MARK: - Reading

	private func read() async {
		guard case let .link(url, title) = item.content else { return }

		do {
			switch item.action {
				case .ask:
					let page = try await PageReader.read(url)
					guard !Task.isCancelled else { return }
					askStore.startChat(with: Self.chatText(for: page, at: url))
					navigation.selectedTab = .ask
					navigation.dismissSheet()

				case .breakDown:
					let page = try await PageReader.read(url)
					guard !Task.isCancelled else { return }
					phase = .ready(SharedText.cut(page.text, to: SharedItem.textLimit))

				case .board:
					let found: String? = if let title {
						title
					} else {
						await Self.pageTitle(of: url)
					}
					guard !Task.isCancelled else { return }
					phase = .ready([found, url.absoluteString].compactMap(\.self).joined(separator: "\n"))
			}
		} catch {
			guard !Task.isCancelled, !(error is CancellationError) else { return }
			phase = .failed((error as? ServiceError)?.message ?? error.localizedDescription)
		}
	}

	/// The model can't open links, so a chat gets what the page says
	private static func chatText(for page: WebPageText, at url: URL) -> String {
		let source = [page.title, url.absoluteString].compactMap(\.self).joined(separator: "\n")
		return SharedText.cut("\(source)\n\n\(page.text)", to: SharedItem.textLimit)
	}

	/// A box still says something with only the link, so a page that won't load is no reason to stop
	private static func pageTitle(of url: URL) async -> String? {
		try? await PageReader.read(url).title
	}
}

// MARK: - Add to Board

/// Which board the shared text goes on. It's chosen here and not in the extension, since boards are only the app's to read.
private struct AddToBoardSheet: View {
	let english: String

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	var body: some View {
		NavigationStack {
			List {
				Section {
					Text(english)
						.lineLimit(4)
						.foregroundStyle(.secondary)
				}

				Section {
					Button("New Board", systemImage: "square.and.pencil") {
						add(to: nil)
					}
					.accessibilityIdentifier("share.board.new")
				}

				if !boardStore.boards.isEmpty {
					Section("Boards") {
						ForEach(boardStore.sortedBoards) { board in
							Button {
								add(to: board.id)
							} label: {
								BoardRow(board: board, isCurrent: false)
							}
							.buttonStyle(.plain)
							.disabled(!board.hasRoom)
						}
					}
				}
			}
			.navigationTitle("Add to Board")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(role: .cancel) {
						navigation.dismissSheet()
					}
					.accessibilityIdentifier("share.board.cancel")
				}
			}
		}
	}

	private func add(to id: Board.ID?) {
		if let id {
			boardStore.open(id)
		} else {
			boardStore.newBoard()
		}
		boardStore.addStatement(english: english)
		navigation.selectedTab = .board
		navigation.dismissSheet()
	}
}
