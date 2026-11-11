//
//  AskStoreTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
@testable import Ergo
import ErgoProtocol
import Foundation
import Testing

/// A chat with one question and, if there is one, its answer
func chat(_ question: String = "What is a fallacy?", answer: String? = "An error in reasoning.") -> AskConversation {
	var conversation = AskConversation()
	conversation.messages = [AskMessage(role: .user, text: question)]
	if let answer {
		conversation.messages.append(AskMessage(role: .assistant, text: answer))
	}
	return conversation
}

/// The conversations on the Ask tab, as far as they can be tested without a server. Anything that sends a question
/// would reach the real one, so only what happens before and around that is here.
@Suite(.cleanDefaults)
struct AskStoreTests {
	// MARK: - Starting

	@Test func aNewStoreHasNoChatsAndShowsTheList() {
		let store = AskStore.test()

		#expect(store.conversations.isEmpty)
		#expect(!store.isChatOpen)
	}

	@Test func aChatThatWasOpenIsOpenAgain() {
		let saved = chat()
		Defaults[.askConversations] = [saved]
		Defaults[.currentAskConversationID] = saved.id

		let store = AskStore()

		#expect(store.isChatOpen)
		#expect(store.current.id == saved.id)
	}

	// MARK: - Opening and starting chats

	@Test func startingAChatOpensAnEmptyOneInTheModeAsked() {
		let store = AskStore.test()

		store.newConversation(mode: .debate)

		#expect(store.isChatOpen)
		#expect(store.current.messages.isEmpty)
		#expect(store.current.mode == .debate)
	}

	@Test func theNormalModeIsStoredAsNothing() {
		let store = AskStore.test()

		store.newConversation(mode: .normal)

		#expect(store.current.mode == nil)
	}

	@Test func anEmptyChatIsReusedAndNotReplaced() {
		let store = AskStore.test()
		store.newConversation()
		let first = store.current.id

		store.newConversation()

		#expect(store.current.id == first)
	}

	@Test func startingAChatFromAnAnsweredOneOpensANewEmptyChat() {
		let answered = chat()
		let store = AskStore.test(answered)
		store.open(answered.id)

		store.newConversation()

		#expect(store.current.id != answered.id)
		#expect(store.current.messages.isEmpty)
		#expect(store.conversations.count == 1)
	}

	@Test func openingAChatRemembersItAndClosingForgetsIt() {
		let saved = chat()
		let store = AskStore.test(saved)

		store.open(saved.id)
		#expect(Defaults[.currentAskConversationID] == saved.id)
		#expect(store.isChatOpen)

		store.closeChat()
		#expect(Defaults[.currentAskConversationID] == nil)
		#expect(!store.isChatOpen)
	}

	// MARK: - Modes

	@Test func aModeIsSetOnAnEmptyChatUntilSomethingIsAsked() {
		let store = AskStore.test()
		store.newConversation()

		store.setMode(.scout, for: store.current.id)

		#expect(store.current.mode == .scout)
		#expect(store.conversations.isEmpty)
	}

	@Test func aModeIsChangedOnASavedChatAndSaved() {
		let saved = chat()
		let store = AskStore.test(saved)

		store.setMode(.debate, for: saved.id)

		#expect(store.conversation(saved.id)?.mode == .debate)
		#expect(Defaults[.askConversations].first?.mode == .debate)

		store.setMode(.normal, for: saved.id)

		#expect(store.conversation(saved.id)?.mode == nil)
	}

	// MARK: - Listing

	@Test func theListIsNewestFirstWithPinnedOnTopAndArchivedApart() {
		var old = chat("Old")
		old.modified = Date(timeIntervalSince1970: 100)
		var middle = chat("Middle")
		middle.modified = Date(timeIntervalSince1970: 200)
		var new = chat("New")
		new.modified = Date(timeIntervalSince1970: 300)
		let store = AskStore.test(old, middle, new)

		store.setPinned(true, old.id)
		store.setArchived(true, middle.id)

		#expect(store.listedConversations.map(\.id) == [old.id, new.id])
		#expect(store.archivedConversations.map(\.id) == [middle.id])
	}

	@Test func archivingUnpinsAndClosesTheOpenChat() {
		let saved = chat()
		let store = AskStore.test(saved)
		store.open(saved.id)
		store.setPinned(true, saved.id)

		store.setArchived(true, saved.id)

		#expect(store.conversation(saved.id)?.isPinned == nil)
		#expect(!store.isChatOpen)
		#expect(store.conversation(saved.id)?.isArchived == true)
	}

	@Test func bringingAChatBackFromTheArchiveListsItAgain() {
		let saved = chat()
		let store = AskStore.test(saved)
		store.setArchived(true, saved.id)

		store.setArchived(false, saved.id)

		#expect(store.listedConversations.map(\.id) == [saved.id])
	}

	@Test func renamingTrimsAndAnEmptyNameGoesBackToTheQuestion() {
		let saved = chat("What is a fallacy?")
		let store = AskStore.test(saved)

		store.rename(saved.id, to: "  Fallacies \n")
		#expect(store.conversation(saved.id)?.title == "Fallacies")

		store.rename(saved.id, to: "")
		#expect(store.conversation(saved.id)?.title == "What is a fallacy?")
	}

	@Test func deletingAChatForgetsItsAttachmentsAndClosesItIfOpen() {
		let saved = chat()
		let store = AskStore.test(saved)
		store.open(saved.id)
		store.attach(.text("Notes"), to: saved.id)

		store.delete(saved.id)

		#expect(store.conversations.isEmpty)
		#expect(store.attachments[saved.id] == nil)
		#expect(!store.isChatOpen)
		#expect(Defaults[.askConversations].isEmpty)
	}

	// MARK: - Attachments

	@Test func anAttachmentWaitsWithItsChat() {
		let store = AskStore.test()
		store.newConversation()
		let id = store.current.id

		store.attach(.text("Some notes"), to: id)

		#expect(store.attachments[id]?.map(\.content) == [.text("Some notes")])
	}

	@Test func theSameThingAttachedTwiceIsAttachedOnce() {
		let store = AskStore.test()
		store.newConversation()
		let id = store.current.id

		store.attach(.text("Some notes"), to: id)
		store.attach(.text("Some notes"), to: id)

		#expect(store.attachments[id]?.count == 1)
	}

	@Test func eachChatKeepsItsOwnAttachments() {
		let first = chat("First")
		let second = chat("Second")
		let store = AskStore.test(first, second)

		store.attach(.text("For the first"), to: first.id)

		#expect(store.attachments[first.id]?.count == 1)
		#expect(store.attachments[second.id] == nil)
	}

	@Test func anAttachmentCanBeEditedAndRemoved() throws {
		let store = AskStore.test()
		store.newConversation()
		let id = store.current.id
		store.attach(.text("Draft"), to: id)
		let attachment = try #require(store.attachments[id]?.first)

		store.updateAttachment(attachment.id, in: id, text: "Final")
		#expect(store.attachments[id]?.first?.content == .text("Final"))

		store.removeAttachment(attachment.id, from: id)
		#expect(store.attachments[id]?.isEmpty == true)
	}

	@Test func startingAChatWithSomethingAttachedKeepsItAsAnUnsentDraft() {
		let store = AskStore.test()

		store.startChat(attaching: .text("Shared text"))

		let draft = store.unsentDraft
		#expect(draft != nil)
		#expect(store.attachments[draft?.id ?? UUID()]?.count == 1)
		#expect(store.conversations.isEmpty)
	}

	@Test func aChatWithNothingAttachedHasNoUnsentDraft() {
		let store = AskStore.test()
		store.newConversation()

		#expect(store.unsentDraft == nil)
	}

	@Test func theUnsentDraftSurvivesOpeningAnotherChat() {
		let other = chat()
		let store = AskStore.test(other)
		store.startChat(attaching: .text("Shared text"))
		let draftID = store.unsentDraft?.id

		store.open(other.id)

		#expect(store.unsentDraft?.id == draftID)
		#expect(store.current.id == other.id)
	}

	@Test func startingAChatAboutABoardTakesTheWaitingAttachmentsAlong() {
		let store = AskStore.test()
		store.startChat(attaching: .text("Shared text"))
		let waiting = store.unsentDraft?.id

		store.newBoardChat(UUID())

		let moved = store.unsentDraft
		#expect(moved != nil)
		#expect(moved?.id != waiting)
		#expect(store.attachments[moved?.id ?? UUID()]?.count == 1)
		#expect(store.attachments[waiting ?? UUID()] == nil)
	}

	// MARK: - A chat about a board

	@Test func openingABoardsChatWithNoneYetStartsAnEmptyOneAboutIt() {
		let board = UUID()
		let store = AskStore.test()

		store.openBoardChat(board)

		#expect(store.current.board == board)
		#expect(store.current.messages.isEmpty)
	}

	@Test func openingABoardsChatFindsTheNewestOne() {
		let board = UUID()
		var older = chat("Older")
		older.board = board
		older.modified = Date(timeIntervalSince1970: 100)
		var newer = chat("Newer")
		newer.board = board
		newer.modified = Date(timeIntervalSince1970: 200)
		let store = AskStore.test(older, newer)

		store.openBoardChat(board)

		#expect(store.current.id == newer.id)
	}

	@Test func openingABoardsChatDoesNotOpenItOnTheAskTab() {
		let board = UUID()
		var existing = chat()
		existing.board = board
		let store = AskStore.test(existing)

		store.openBoardChat(board)

		#expect(!store.isChatOpen)
	}

	@Test func aBoardChatThatIsArchivedIsNotReopened() {
		let board = UUID()
		var archived = chat()
		archived.board = board
		archived.isArchived = true
		let store = AskStore.test(archived)

		store.openBoardChat(board)

		#expect(store.current.id != archived.id)
		#expect(store.current.board == board)
	}

	@Test func aNewBoardChatLeavesTheAnsweredOneInTheList() {
		let board = UUID()
		var answered = chat()
		answered.board = board
		let store = AskStore.test(answered)
		store.openBoardChat(board)

		store.newBoardChat(board)

		#expect(store.current.id != answered.id)
		#expect(store.current.messages.isEmpty)
		#expect(store.current.board == board)
		#expect(store.conversations.count == 1)
	}

	@Test func anEmptyChatForABoardIsNotReplacedByAnother() {
		let board = UUID()
		let store = AskStore.test()
		store.openBoardChat(board)
		let first = store.current.id

		store.newBoardChat(board)

		#expect(store.current.id == first)
	}

	@Test func startingAFreshChatForgetsTheBoardOfAnEmptyOne() {
		let store = AskStore.test()
		store.openBoardChat(UUID())

		store.newConversation()

		#expect(store.current.board == nil)
	}

	// MARK: - Follow-ups

	@Test func aFollowUpWaitsInTheComposerUntilTaken() {
		let store = AskStore.test()

		store.draftFollowUp("What about the converse?")

		#expect(store.waitingDraft == "What about the converse?")
		#expect(store.takeWaitingDraft() == "What about the converse?")
		#expect(store.takeWaitingDraft() == nil)
	}

	// MARK: - Sending, as far as it can be tried

	@Test func aQuestionWithNothingInItIsNotSent() {
		let store = AskStore.test()
		store.newConversation()

		store.send("  \n ", account: TranslationAccount(signedIn: nil))

		#expect(store.current.messages.isEmpty)
		#expect(store.runs.isEmpty)
		#expect(store.current.pending == nil)
	}

	@Test func aQuestionToAChatThatIsntThereIsNotSent() {
		let store = AskStore.test()

		store.send("Hello?", in: UUID(), account: TranslationAccount(signedIn: nil))

		#expect(store.conversations.isEmpty)
		#expect(store.runs.isEmpty)
	}

	@Test func retryingAChatThatIsntThereDoesNothing() {
		let store = AskStore.test()

		store.retry(UUID(), account: TranslationAccount(signedIn: nil))

		#expect(store.runs.isEmpty)
	}

	@Test func stoppingAChatWithNoAnswerRunningChangesNothing() {
		let saved = chat()
		let store = AskStore.test(saved)

		store.stop(saved.id)

		#expect(store.conversation(saved.id)?.messages.count == 2)
	}

	@Test func openingTheAppWithNothingInterruptedStartsNoRun() {
		let store = AskStore.test(chat())

		store.resumeInterrupted(account: TranslationAccount(signedIn: nil))

		#expect(store.runs.isEmpty)
	}

	// MARK: - What the server is sent

	@Test func theServerGetsTheNewestMessagesThatFit() {
		let half = String(repeating: "a", count: AskRequest.characterLimit / 2)
		let messages = [
			AskMessage(role: .user, text: half),
			AskMessage(role: .assistant, text: half),
			AskMessage(role: .user, text: "And now?"),
		]

		let sent = AskStore.request(from: messages)

		#expect(sent.map(\.text) == ["And now?"])
	}

	@Test func aCutNeverStartsOnAnAnswer() {
		let quarter = String(repeating: "a", count: AskRequest.characterLimit / 4)
		let messages = [
			AskMessage(role: .user, text: quarter),
			AskMessage(role: .assistant, text: quarter),
			AskMessage(role: .user, text: quarter),
			AskMessage(role: .assistant, text: quarter),
			AskMessage(role: .user, text: "Last"),
		]

		let sent = AskStore.request(from: messages)

		#expect(sent.first?.role == .user)
		#expect(sent.last?.text == "Last")
	}

	@Test func aShortChatGoesWhole() {
		let sent = AskStore.request(from: chat("Q", answer: "A").messages + [AskMessage(role: .user, text: "Q2")])

		#expect(sent.map(\.text) == ["Q", "A", "Q2"])
		#expect(sent.map(\.role) == [.user, .assistant, .user])
	}

	@Test func whatWasAttachedGoesAfterTheQuestion() {
		let message = AskMessage(role: .user, text: "Is this valid?", attachments: [AskAttachment(content: .text("All men are mortal."))])

		let sent = AskStore.request(from: [message])

		#expect(sent.first?.text == "Is this valid?\n\nAttached text:\nAll men are mortal.")
	}
}
