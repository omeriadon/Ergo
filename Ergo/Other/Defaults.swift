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

	/// Synced as a record per page, statement and link, through `PageStore`. Drafts aren't in here, so they never sync.
	static let pages = Key<[LogicPage]>("pages", default: [])

	static let ditherEnabled = Key<Bool>("ditherEnabled", default: true)

	static let translationProvider = Key<Provider>("translationProvider", default: .claude)
}

// MARK: - This device only

extension Defaults.Keys {
	static let selectedTab = Key<AppTab>("selectedTab", default: .check)

	static let libraryPath = Key<[LibraryRoute]>("libraryPath", default: [])
	static let debatePath = Key<[DebateRoute]>("debatePath", default: [])

	static let presentedSheet = Key<AppSheet?>("presentedSheet", default: nil)

	static let libraryGeneralSearchText = Key<String>("libraryGeneralSearchText", default: "")

	static let currentPageID = Key<UUID?>("currentPageID", default: nil)

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

	/// Set while this device is signed in, with Apple or an email, which sync needs. This device only.
	static let signedInAccount = Key<SignedInAccount?>("signedInAccount", default: nil)

	/// Breaks ties between this install's sync stamps and other devices'. Made once, kept across sign-outs.
	static let syncDeviceID = Key<String?>("syncDeviceID", default: nil)

	/// What's been synced and what's waiting to be. Never replaced, only `reset()`, so nothing pending is lost.
	/// Named for the canvas: the older `syncState` held page records with `content`, which the server now refuses,
	/// so keeping it would leave sync failing forever.
	static let syncState = Key<SyncReplica?>("canvasSyncState", default: nil)
}

extension Provider: @retroactive Defaults.Serializable {}
extension SyncReplica: @retroactive Defaults.Serializable {}
