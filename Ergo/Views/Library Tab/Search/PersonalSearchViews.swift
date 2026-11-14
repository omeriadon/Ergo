//
//  PersonalSearchViews.swift
//  Ergo
//

import Defaults
import ErgoLogic
import SwiftUI

// The Library's search also finds the person's own boards, scratchpads and chats. They're listed under the library's
// results, each with its kind's own row, and open the way the sidebar opens them.

// MARK: - Searching

extension View {
	/// Fills `results` with the boards, scratchpads and chats matching `query`, matched off the main actor
	func personalSearch(query: String, isPresented: Bool, results: Binding<PersonalSearchResults>) -> some View {
		modifier(PersonalSearchTask(query: query, isPresented: isPresented, results: results))
	}
}

private struct PersonalSearchTask: ViewModifier {
	let query: String
	let isPresented: Bool
	@Binding var results: PersonalSearchResults

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(ScratchpadStore.self)
	private var scratchpadStore

	@Environment(AskStore.self)
	private var askStore

	@Environment(TranslationAccount.self)
	private var account

	@Default(.logicLetters) private var logicLetters

	func body(content: Content) -> some View {
		content
			.task(id: "\(isPresented)-\(query)") {
				await search()
			}
	}

	private func search() async {
		guard isPresented, !query.isEmpty else {
			// Only clear what's there, since every appearance of the tab runs this task
			if !results.isEmpty {
				results = PersonalSearchResults()
			}
			return
		}
		do {
			// The same pause as the library's search, so typing doesn't search every letter
			try await Task.sleep(for: .milliseconds(120))
			let query = query
			let boards = boardDocuments
			let scratchpads = scratchpadDocuments
			// The Ask tab is a sign-in prompt without an account, so its chats can't be opened
			let chats = account.isSignedInHere ? chatDocuments : []

			async let boardHits = PersonalSearch.ranked(boards, query: query)
			async let scratchpadHits = PersonalSearch.ranked(scratchpads, query: query)
			async let chatHits = PersonalSearch.ranked(chats, query: query)
			let found = try await PersonalSearchResults(boards: boardHits, scratchpads: scratchpadHits, chats: chatHits)
			try Task.checkCancellation()
			results = found
		} catch is CancellationError {
			return
		} catch {
			results = PersonalSearchResults()
		}
	}

	// MARK: - Snapshots

	/// Board titles aren't worked out here, since that sorts each board's statements: its name is the title, and its
	/// statements, which an untitled board's title comes from, are the text.
	private var boardDocuments: [PersonalSearchDocument] {
		let archived = boardStore.archivedIDs
		return boardStore.sortedBoards.map { board in
			PersonalSearchDocument(
				id: board.id,
				titles: [board.name],
				bodies: board.statements.map(\.english) + board.sources.map(\.content.searchText),
				isArchived: archived.contains(board.id)
			)
		}
	}

	private var scratchpadDocuments: [PersonalSearchDocument] {
		let letters = LogicLetters.resolved(logicLetters)
		return scratchpadStore.sortedScratchpads.map { scratchpad in
			PersonalSearchDocument(
				id: scratchpad.id,
				titles: [scratchpad.name],
				bodies: [scratchpad.english, scratchpad.logic.map { $0.glyph(letters: letters) }.joined()]
			)
		}
	}

	private var chatDocuments: [PersonalSearchDocument] {
		askStore.sortedConversations.map { conversation in
			PersonalSearchDocument(
				id: conversation.id,
				titles: [conversation.name, conversation.suggestedTitle ?? ""],
				bodies: conversation.messages.map(\.text),
				isArchived: conversation.isArchived == true
			)
		}
	}
}

private extension BoardSource.Content {
	nonisolated var searchText: String {
		switch self {
			case let .text(text):
				text
			case let .link(url, title):
				[title, url.absoluteString].compactMap(\.self).joined(separator: " ")
		}
	}
}

// MARK: - Results

/// The boards, scratchpads and chats found, a heading over each kind
struct PersonalSearchSections: View {
	let results: PersonalSearchResults

	var body: some View {
		if !results.boards.isEmpty {
			PersonalSearchHeader("Boards")
			ForEach(results.boards) { hit in
				BoardSearchResultRow(hit: hit)
			}
		}

		if !results.scratchpads.isEmpty {
			PersonalSearchHeader("Scratchpads")
			ForEach(results.scratchpads) { hit in
				ScratchpadSearchResultRow(hit: hit)
			}
		}

		if !results.chats.isEmpty {
			PersonalSearchHeader("Chats")
			ForEach(results.chats) { hit in
				ChatSearchResultRow(hit: hit)
			}
		}
	}
}

struct PersonalSearchHeader: View {
	let title: LocalizedStringKey

	init(_ title: LocalizedStringKey) {
		self.title = title
	}

	var body: some View {
		Text(title)
			.font(.headline)
			.foregroundStyle(.secondary)
			.padding(.horizontal, 7)
			.padding(.top, 10)
			.accessibilityAddTraits(.isHeader)
			.transition(.opacity)
	}
}

// Each row looks its item up when drawn, so one deleted since the search is left out

private struct BoardSearchResultRow: View {
	let hit: PersonalSearchHit

	@Environment(BoardStore.self)
	private var boardStore

	var body: some View {
		if let board = boardStore.boards.first(where: { $0.id == hit.id }) {
			PersonalSearchResultButton(hit: hit, item: .board(board.id), kind: "board") {
				BoardRow(
					board: board,
					isCurrent: false,
					share: boardStore.shares[board.id],
					isPinned: boardStore.pinnedIDs.contains(board.id)
				)
			}
		}
	}
}

private struct ScratchpadSearchResultRow: View {
	let hit: PersonalSearchHit

	@Environment(ScratchpadStore.self)
	private var scratchpadStore

	@Default(.logicLetters) private var logicLetters

	var body: some View {
		if let scratchpad = scratchpadStore.scratchpads.first(where: { $0.id == hit.id }) {
			PersonalSearchResultButton(hit: hit, item: .scratchpad(scratchpad.id), kind: "scratchpad") {
				ScratchpadRow(scratchpad: scratchpad, letters: LogicLetters.resolved(logicLetters))
			}
		}
	}
}

private struct ChatSearchResultRow: View {
	let hit: PersonalSearchHit

	@Environment(AskStore.self)
	private var askStore

	var body: some View {
		if let conversation = askStore.conversations.first(where: { $0.id == hit.id }) {
			PersonalSearchResultButton(hit: hit, item: .chat(conversation.id), kind: "chat") {
				AskHistoryRow(conversation: conversation, isAnswering: askStore.runs[conversation.id] != nil)
			}
		}
	}
}

/// A kind's own row, with the matching text under it, opening the item as the sidebar would
private struct PersonalSearchResultButton<Row: View>: View {
	let hit: PersonalSearchHit
	let item: SidebarItem
	let kind: String
	@ViewBuilder let row: Row

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(ScratchpadStore.self)
	private var scratchpadStore

	@Environment(AskStore.self)
	private var askStore

	@Environment(TranslationAccount.self)
	private var account

	var body: some View {
		Button {
			navigation.select(
				item,
				boards: boardStore,
				scratchpads: scratchpadStore,
				ask: askStore,
				isSignedIn: account.isSignedInHere
			)
		} label: {
			VStack(alignment: .leading, spacing: 6) {
				row
				PersonalSearchHitDetail(hit: hit)
			}
			.contentShape(Rectangle())
		}
		.accessibilityIdentifier("library.search.\(kind).\(hit.id.uuidString)")
		.padding(.horizontal, 14)
		.padding(.vertical, 13)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
		.contentShape(RoundedRectangle(cornerRadius: 18))
		.transition(.opacity)
	}
}

/// The text the query was found in, and whether the item's archived
private struct PersonalSearchHitDetail: View {
	let hit: PersonalSearchHit

	var body: some View {
		if let snippet = hit.snippet {
			Text(snippet)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.lineLimit(2)
				.frame(maxWidth: .infinity, alignment: .leading)
		}

		if hit.isArchived {
			Label("Archived", systemImage: "archivebox")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
}
