//
//  Defaults.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import Foundation

// Every key needs a sync decision. Synced ones are the user's stuff, and are listed in `SyncedDefaults.swift`;
// everything about where this screen is, or where the server is, stays on the device.

// MARK: - Synced

extension Defaults.Keys {
	/// Synced one record per bookmark, never as a whole set
	static let bookmarks = Key<Set<CatalogReference>>(
		"bookmarks",
		default: []
	)

	static let logicLetters = Key<[String]>("logicLetters", default: LogicLetters.defaults)

	/// Synced as a record per board, statement and link, through `BoardStore`. Drafts aren't in here, so they never sync.
	static let boards = Key<[Board]>("boards", default: [])

	/// Synced as a record per scratchpad, through `ScratchpadStore`. Drafts aren't in here, so they never sync.
	static let scratchpads = Key<[LogicScratchpad]>("scratchpads", default: [])

	static let ditherEnabled = Key<Bool>("ditherEnabled", default: true)

	static let hapticsEnabled = Key<Bool>("hapticsEnabled", default: true)

	static let translationProvider = Key<Provider>("translationProvider", default: .claude)

	/// What the person tells the agent about how to answer, like how concise to be. Sent with every Ask and board analysis.
	static let agentInstructions = Key<String>("agentInstructions", default: "")
}

// MARK: - This device only

extension Defaults.Keys {
	static let selectedTab = Key<AppTab>("selectedTab", default: .board)

	/// Conversations stay on the device for now. The server only ever sees the one being answered, and keeps that answer for
	/// an hour after it ends, in memory, in case the app was closed before it arrived.
	static let askConversations = Key<[AskConversation]>("askConversations", default: [])

	static let currentAskConversationID = Key<AskConversation.ID?>("currentAskConversationID", default: nil)

	/// The breakdown the server is working on, so closing the app doesn't lose it. Names a run on this device's account.
	static let pendingBreakDown = Key<PendingBreakDown?>("pendingBreakDown", default: nil)

	static let libraryPath = Key<[LibraryRoute]>("libraryPath", default: [])

	static let askThreadSelected = Key<String?>("askThreadSelected", default: nil)

	static let presentedSheet = Key<AppSheet?>("presentedSheet", default: nil)

	static let boardSheet = Key<BoardSheet?>("boardSheet", default: nil)

	static let logicSheet = Key<LogicSheet?>("logicSheet", default: nil)

	static let librarySheet = Key<LibrarySheet?>("librarySheet", default: nil)

	static let libraryGeneralSearchText = Key<String>("libraryGeneralSearchText", default: "")

	static let currentBoardID = Key<UUID?>("currentBoardID", default: nil)

	static let currentScratchpadID = Key<UUID?>("currentScratchpadID", default: nil)

	static let logicPath = Key<[LogicRoute]>("logicPath", default: [])

	/// Which server a debug build talks to. Release builds ignore it and always use production.
	/// It says where the server is, so it can't come from the server.
	static let serverEnvironment = Key<ServerEnvironment>("serverEnvironment", default: .production)

	/// The Mac's address for `ServerEnvironment.thisMac`, only read in debug builds. Empty means not set up.
	/// Not synced, for the same reason as `serverEnvironment`.
	static let translationServer = Key<String>("translationServer", default: "")

	static let lastIndexedVersion = Key<String>(
		"lastIndexedVersion",
		default: ""
	)

	/// The course lessons finished on this device. Not synced, since it's only a tick beside each one.
	static let logicCourseFinished = Key<Set<String>>("logicCourseFinished", default: [])

	/// Set while this device is signed in, with Apple or an email, which sync needs. This device only.
	static let signedInAccount = Key<SignedInAccount?>("signedInAccount", default: nil)

	/// Breaks ties between this install's sync stamps and other devices'. Made once, kept across sign-outs.
	static let syncDeviceID = Key<String?>("syncDeviceID", default: nil)

	/// What's been synced and what's waiting to be. Never replaced, only `reset()`, so nothing pending is lost.
	/// Named for the canvas: the older `syncState` held board records with `content`, which the server now refuses,
	/// so keeping it would leave sync failing forever.
	static let syncState = Key<SyncReplica?>("canvasSyncState", default: nil)

	/// What other people see this person called on a board they share. Only ever typed in here, never taken from the
	/// email. Not synced: the server keeps the name that each board was joined with, and this only fills in the next one.
	static let sharingName = Key<String>("sharingName", default: "")
}

extension Provider: @retroactive Defaults.Serializable {}
extension SyncReplica: @retroactive Defaults.Serializable {}
