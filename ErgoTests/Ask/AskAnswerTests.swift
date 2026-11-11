//
//  AskAnswerTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

@testable import Ergo
import ErgoCatalog
import ErgoProtocol
import Foundation
import Testing

/// What the store does with each thing the server says while it writes an answer
@Suite(.cleanDefaults)
struct AskAnswerTests {
	let answer = UUID()

	// MARK: - Text and tools

	@Test func anAnswerGrowsAsItArrives() {
		let asked = chat("Hello?", answer: nil)
		let store = AskStore.test(asked)

		store.apply(.text("A fallacy "), to: answer, in: asked.id)
		store.apply(.text("is an error."), to: answer, in: asked.id)

		let messages = store.conversation(asked.id)?.messages
		#expect(messages?.count == 2)
		#expect(messages?.last?.id == answer)
		#expect(messages?.last?.role == .assistant)
		#expect(messages?.last?.text == "A fallacy is an error.")
	}

	@Test func eachToolIsNotedOnce() {
		let asked = chat("Hello?", answer: nil)
		let store = AskStore.test(asked)
		let search = AskToolActivity(tool: "search_library", summary: "Searching the library", record: "Searched the library")

		store.apply(.tool(search), to: answer, in: asked.id)
		store.apply(.tool(search), to: answer, in: asked.id)

		#expect(store.conversation(asked.id)?.messages.last?.tools == ["Searched the library"])
	}

	@Test func eachButtonIsAddedOnce() {
		let asked = chat("Hello?", answer: nil)
		let store = AskStore.test(asked)
		let button = AskAction(title: "Open Bookmarks", intent: .openBookmarks)

		store.apply(.action(button), to: answer, in: asked.id)
		store.apply(.action(button), to: answer, in: asked.id)

		#expect(store.conversation(asked.id)?.messages.last?.actions == [button])
	}

	@Test func theServerNamesTheChatButAPersonsNameWins() {
		let asked = chat("Hello?", answer: nil)
		let store = AskStore.test(asked)

		store.apply(.title("Fallacies"), to: answer, in: asked.id)
		#expect(store.conversation(asked.id)?.title == "Fallacies")

		store.rename(asked.id, to: "Mine")
		store.apply(.title("Something else"), to: answer, in: asked.id)
		#expect(store.conversation(asked.id)?.title == "Mine")
	}

	@Test func aModeRequestWaitsForTheAnswer() {
		let asked = chat("Hello?", answer: nil)
		let store = AskStore.test(asked)
		let request = AskModeRequest(mode: .debate, reason: "Argue about free will")

		store.apply(.modeRequest(request), to: answer, in: asked.id)

		let message = store.conversation(asked.id)?.messages.last
		#expect(message?.modeRequest == request)
		#expect(message?.modeAccepted == nil)
	}

	@Test func anEventForAChatThatIsGoneIsDropped() {
		let store = AskStore.test()

		store.apply(.text("Hello"), to: answer, in: UUID())

		#expect(store.conversations.isEmpty)
	}

	@Test func eventsThatSayNothingChangeNothing() {
		let asked = chat("Hello?", answer: nil)
		let store = AskStore.test(asked)

		store.apply(.finished, to: answer, in: asked.id)
		store.apply(.unknown, to: answer, in: asked.id)

		#expect(store.conversation(asked.id)?.messages.count == 1)
	}

	// MARK: - Changes to the board

	/// A chat about a board, and the store of boards it changes
	struct BoardChat {
		let boards: BoardStore
		let store: AskStore
		let id: UUID
		let board: Board
		let rain: Statement

		init(canEdit: Bool = true) {
			let rain = card("Rain")
			let board = Board([rain, card("Wet", y: 200)])
			let boards = BoardStore.test(board)
			if !canEdit {
				boards.shares[board.id] = .invited(to: board, as: .viewer)
			}

			var conversation = chat("Add a card", answer: nil)
			conversation.board = board.id
			let store = AskStore.test(conversation)
			store.boardStore = boards

			self.boards = boards
			self.store = store
			id = conversation.id
			self.board = board
			self.rain = rain
		}

		var applied: [UUID]? {
			store.conversation(id)?.appliedEdits
		}

		var lastMessage: AskMessage? {
			store.conversation(id)?.messages.last
		}
	}

	@Test func aChangeTheModelAsksForIsMadeOnTheBoard() {
		let chat = BoardChat()
		let sun = UUID()
		let edit = AskBoardEdit(change: .addCard(id: sun, english: "Sun", near: nil))

		chat.store.apply(.boardEdit(edit), to: answer, in: chat.id)

		#expect(chat.boards.statement(sun)?.english == "Sun")
		#expect(chat.applied == [edit.id])
		#expect(chat.lastMessage?.edits == ["Added “Sun”"])
	}

	/// The server says the whole answer again when it's picked up after the app was closed
	@Test func hearingTheSameChangeAgainDoesNotMakeItTwice() {
		let chat = BoardChat()
		let edit = AskBoardEdit(change: .addCard(id: UUID(), english: "Sun", near: nil))

		chat.store.apply(.boardEdit(edit), to: answer, in: chat.id)
		chat.store.apply(.boardEdit(edit), to: answer, in: chat.id)

		#expect(chat.boards.current.statements.count == 3)
		#expect(chat.applied == [edit.id])
	}

	@Test func aChangeThatCantBeMadeIsSaidSoAndNotTriedAgain() {
		let chat = BoardChat()
		let edit = AskBoardEdit(change: .editCard(id: UUID(), english: "Nothing there"))

		chat.store.apply(.boardEdit(edit), to: answer, in: chat.id)

		#expect(chat.lastMessage?.edits == ["Couldn't change the board"])
		#expect(chat.applied == [edit.id])
	}

	@Test func aViewOnlyBoardIsNotChanged() {
		let chat = BoardChat(canEdit: false)
		let edit = AskBoardEdit(change: .editCard(id: chat.rain.id, english: "Changed"))

		chat.store.apply(.boardEdit(edit), to: answer, in: chat.id)

		#expect(chat.boards.statement(chat.rain.id)?.english == "Rain")
		#expect(chat.lastMessage?.edits == ["Couldn't change the board"])
	}

	@Test func aChatNotAboutABoardMakesNoChanges() {
		let asked = chat("Hello?", answer: nil)
		let store = AskStore.test(asked)
		let edit = AskBoardEdit(change: .addCard(id: UUID(), english: "Sun", near: nil))

		store.apply(.boardEdit(edit), to: answer, in: asked.id)

		#expect(store.conversation(asked.id)?.appliedEdits == nil)
	}

	// MARK: - Taking changes back

	@Test func anAnswersChangesCanBeTakenBack() {
		let chat = BoardChat()
		let before = chat.board.statements
		let edit = AskBoardEdit(change: .deleteCard(id: chat.rain.id))
		chat.store.apply(.boardEdit(edit), to: answer, in: chat.id)
		#expect(chat.store.canUndoEdits(of: answer))

		chat.store.undoEdits(of: answer, in: chat.id)

		#expect(chat.boards.current.statements == before)
		#expect(chat.lastMessage?.editsUndone == true)
		#expect(!chat.store.canUndoEdits(of: answer))
	}

	@Test func anAnswerThatChangedNothingHasNothingToTakeBack() {
		let asked = chat("Hello?", answer: nil)
		let store = AskStore.test(asked)

		#expect(!store.canUndoEdits(of: answer))
	}
}

/// The values a chat is made of
struct AskConversationTests {
	@Test func aChatIsTitledByItsNameThenTheServersThenTheQuestion() {
		var conversation = chat("What is a fallacy?\nAnd why?", answer: nil)
		#expect(conversation.title == "What is a fallacy?")

		conversation.suggestedTitle = "Fallacies"
		#expect(conversation.title == "Fallacies")

		conversation.name = "My chat"
		#expect(conversation.title == "My chat")
	}

	@Test func aChatWithNoQuestionIsNewChat() {
		#expect(AskConversation().title == "New Chat")
	}

	@Test func aQuestionOfOnlyAttachmentsIsTitledByTheFirstOne() {
		var conversation = AskConversation()
		conversation.messages = [AskMessage(role: .user, text: "", attachments: [AskAttachment(content: .text("Notes on logic\nmore"))])]

		#expect(conversation.title == "Notes on logic")
	}

	@Test func eachAttachmentSentIsListedOnce() {
		let notes = AskAttachment(content: .text("Notes"))
		var conversation = AskConversation()
		conversation.messages = [
			AskMessage(role: .user, text: "One", attachments: [notes]),
			AskMessage(role: .user, text: "Two", attachments: [AskAttachment(content: .text("Notes"))]),
		]

		#expect(conversation.sentAttachments.count == 1)
	}

	@Test func theModelIsToldWhatWasAttached() throws {
		let page = try AskAttachment(content: .link(#require(URL(string: "https://example.com/post")), title: "A post", text: "Page text."))
		let unreadable = try AskAttachment(content: .link(#require(URL(string: "https://example.com/other")), title: nil, text: nil))

		#expect(page.requestText == "Attached web page: A post\nhttps://example.com/post\n\nPage text.")
		#expect(unreadable.requestText.hasSuffix("Its text couldn't be read."))
	}

	@Test func aLinkIsShownWithoutTheStartOfItsAddress() throws {
		let link = try AskAttachment(content: .link(#require(URL(string: "https://www.example.com/post")), title: nil, text: nil))

		#expect(link.displayURL == "example.com/post")
		#expect(link.title == "example.com/post")
	}

	@Test func aQuestionWithNoTextIsJustItsAttachments() {
		let message = AskMessage(role: .user, text: "", attachments: [AskAttachment(content: .text("Notes"))])

		#expect(message.requestText == "Attached text:\nNotes")
	}

	@Test func aChatSurvivesBeingSaved() throws {
		var conversation = chat()
		conversation.mode = .debate
		conversation.board = UUID()
		conversation.appliedEdits = [UUID()]
		conversation.pending = .init(run: UUID(), answer: UUID(), started: Date(timeIntervalSince1970: 1000))

		let data = try JSONEncoder().encode(conversation)

		#expect(try JSONDecoder().decode(AskConversation.self, from: data) == conversation)
	}

	/// Chats saved before a field existed still open
	@Test func aChatSavedBeforeNewerFieldsStillReads() throws {
		let json = """
		{"id":"6F1C2E9A-3B4D-4E5F-8A9B-0C1D2E3F4A5B","created":0,"modified":0,"name":"","messages":[]}
		"""

		let conversation = try JSONDecoder().decode(AskConversation.self, from: Data(json.utf8))

		#expect(conversation.mode == nil)
		#expect(conversation.board == nil)
		#expect(conversation.appliedEdits == nil)
		#expect(conversation.isPinned == nil)
	}
}

/// Whether a link or button from the model can be followed here, and what following it does
@Suite(.cleanDefaults)
struct AskIntentsTests {
	/// A real entry from this app's library, as the server names it
	static var libraryEntry: (category: String, id: String)? {
		let parts = LibraryCatalog.entryIDs.sorted().first?.split(separator: "/", maxSplits: 1).map(String.init)
		guard let parts, parts.count == 2 else { return nil }
		return (parts[0], parts[1])
	}

	// MARK: - Can it run

	@Test func tabsThisAppHasCanBeOpened() {
		for tab in ["board", "logic", "ask", "library"] {
			#expect(AskIntents.canRun(.openTab(tab)))
		}
	}

	@Test func aTabThisAppDoesntHaveCantBeOpened() {
		#expect(!AskIntents.canRun(.openTab("settings")))
	}

	/// The server sends the library's own category names, so the app has to know every one
	@Test func everyCategoryTheServerKnowsIsOneTheAppCanShow() {
		let app = Set(LibraryContent.allCases.map(\.rawValue))

		#expect(Set(LibraryCatalog.categories) == app)
	}

	@Test func listsThisAppHasCanBeShown() {
		for category in LibraryContent.allCases {
			#expect(AskIntents.canRun(.showLibraryList(category: category.rawValue)))
		}
		#expect(!AskIntents.canRun(.showLibraryList(category: "spells")))
	}

	@Test func aLibraryEntryThisAppHasCanBeOpened() throws {
		let entry = try #require(Self.libraryEntry)

		#expect(AskIntents.canRun(.openLibraryEntry(category: entry.category, id: entry.id)))
	}

	/// The server's library can be newer than the one in this app
	@Test func aLibraryEntryThisAppDoesntHaveCantBeOpened() throws {
		let entry = try #require(Self.libraryEntry)

		#expect(!AskIntents.canRun(.openLibraryEntry(category: entry.category, id: "an-entry-from-the-future")))
		#expect(!AskIntents.canRun(.openLibraryEntry(category: "spells", id: entry.id)))
	}

	@Test func bookmarksCanAlwaysBeOpened() {
		#expect(AskIntents.canRun(.openBookmarks))
	}

	@Test func aFollowUpNeedsSomethingToAsk() {
		#expect(AskIntents.canRun(.askFollowUp("What about the converse?")))
		#expect(!AskIntents.canRun(.askFollowUp("  \n")))
	}

	@Test func somethingFromANewerServerCantBeRun() {
		#expect(!AskIntents.canRun(.unknown("ergo://intent/teleport")))
	}

	// MARK: - Running it

	@Test func openingATabRevealsItWithNothingOverIt() {
		let navigation = NavigationManager()
		navigation.presentSheet(AppSheet.plus)

		AskIntents.run(.openTab("library"), navigation: navigation, store: AskStore.test())

		#expect(navigation.selectedTab == .library)
		#expect(navigation.visibleSheet == nil)
	}

	@Test func openingBookmarksGoesToThemOnTheLibraryTab() {
		let navigation = NavigationManager()

		AskIntents.run(.openBookmarks, navigation: navigation, store: AskStore.test())

		#expect(navigation.selectedTab == .library)
		#expect(navigation.libraryPath.last == .bookmarks)
	}

	@Test func showingAListOpensItOnTheLibraryTab() {
		let navigation = NavigationManager()

		AskIntents.run(.showLibraryList(category: "fallacies"), navigation: navigation, store: AskStore.test())

		#expect(navigation.libraryPath.last == .category(.fallacies))
	}

	@Test func openingAnEntryOpensItsPage() throws {
		let entry = try #require(Self.libraryEntry)
		let navigation = NavigationManager()

		AskIntents.run(.openLibraryEntry(category: entry.category, id: entry.id), navigation: navigation, store: AskStore.test())

		#expect(navigation.libraryPath.count == 1)
		#expect(navigation.selectedTab == .library)
	}

	/// A follow-up is left in the composer for the person to change, and is never sent
	@Test func aFollowUpIsOnlyLeftInTheComposer() {
		let navigation = NavigationManager()
		let store = AskStore.test(chat())

		AskIntents.run(.askFollowUp("What about the converse?"), navigation: navigation, store: store)

		#expect(store.waitingDraft == "What about the converse?")
		#expect(store.conversations.first?.messages.count == 2)
		#expect(store.runs.isEmpty)
	}

	@Test func somethingUnknownDoesNothing() {
		let navigation = NavigationManager()

		AskIntents.run(.unknown("ergo://intent/teleport"), navigation: navigation, store: AskStore.test())

		#expect(navigation.selectedTab == .board)
		#expect(navigation.visibleSheet == nil)
	}
}
