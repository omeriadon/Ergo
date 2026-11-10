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

		/// The text to break down
		case ready(String)

		/// What's going on the board
		case forBoard(BoardSource.Content)
	}

	let item: SharedItem

	/// The source on the current board this is a breakdown of, when it didn't come from the share sheet
	private let existing: BoardSource.ID?

	@Environment(NavigationManager.self)
	private var navigation

	@State private var phase: Phase
	@State private var attempt = 0

	init(item: SharedItem, existing: BoardSource.ID? = nil) {
		self.item = item
		self.existing = existing
		if item.action == .board, case .text = item.content {
			_phase = State(initialValue: .forBoard(BoardSource.Content(item.content)))
		} else if case let .text(text) = item.content {
			_phase = State(initialValue: .ready(text))
		} else {
			_phase = State(initialValue: .reading)
		}
	}

	var body: some View {
		content
			.task(id: attempt) {
				switch phase {
					case .reading, .failed:
						await read()
					case .ready, .forBoard:
						break
				}
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
				BreakDownSheet(shared: text, input: BoardSource.Content(item.content), existing: existing)

			case let .forBoard(content):
				AddToBoardSheet(content: content)
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
					navigation.presentSheet(.addToChat(.link(url, title: page.title, text: SharedText.cut(page.text, to: SharedItem.textLimit))))

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
					phase = .forBoard(.link(url, title: found))
			}
		} catch {
			guard !Task.isCancelled, !(error is CancellationError) else { return }
			phase = .failed((error as? ServiceError)?.message ?? error.localizedDescription)
		}
	}

	/// A card still says something with only the link, so a page that won't load is no reason to stop
	private static func pageTitle(of url: URL) async -> String? {
		try? await PageReader.read(url).title
	}
}

// MARK: - Breaking down a source

/// Breaks down a source already on the board, reading the page first when it's a link
struct SourceBreakDownSheet: View {
	let id: BoardSource.ID

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	var body: some View {
		if let source = boardStore.source(id) {
			SharedItemSheet(item: SharedItem(content: source.content.shared, action: .breakDown), existing: id)
		} else {
			// Gone since this sheet was last open, on another board or another device
			Color.clear
				.onAppear {
					navigation.dismissSheet()
				}
		}
	}
}

// MARK: - Add to Board

/// Which board what was shared goes on, as a source. It's chosen here and not in the extension, since boards are only the app's to read.
private struct AddToBoardSheet: View {
	let content: BoardSource.Content

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	/// A board this person can only view can't take a source
	private var choices: [Board] {
		boardStore.listedBoards.filter { boardStore.canEdit($0.id) }
	}

	var body: some View {
		NavigationStack {
			List {
				Section {
					Text(content.title)
						.lineLimit(4)
						.foregroundStyle(.secondary)
				}

				Section {
					Button("New Board", systemImage: "square.and.pencil") {
						add(to: nil)
					}
					.accessibilityIdentifier("share.board.new")
				}

				if !choices.isEmpty {
					Section("Boards") {
						ForEach(choices) { board in
							Button {
								add(to: board.id)
							} label: {
								BoardRow(board: board, isCurrent: false)
							}
							.buttonStyle(.plain)
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
		boardStore.addSource(content)
		navigation.reveal(.board)
	}
}
