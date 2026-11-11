//
//  ErgoApp.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import AppIntents
import CoreSpotlight
import ErgoProtocol
import ErgoShare
import SwiftUI

@main
struct ErgoApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	@State private var navigation = NavigationManager()
	@State private var catalog = CatalogStore()
	@State private var boardStore: BoardStore
	@State private var scratchpadStore: ScratchpadStore
	@State private var askStore: AskStore
	@State private var analysisStore: BoardAnalysisStore
	@State private var translationAccount: TranslationAccount
	@State private var purchases: PurchaseStore
	@State private var sync: SyncController

	@Environment(\.scenePhase)
	private var scenePhase

	init() {
		let navigation = NavigationManager()
		let catalog = CatalogStore()
		let boardStore = BoardStore()
		let scratchpadStore = ScratchpadStore()
		let translationAccount = TranslationAccount()
		let analysisStore = BoardAnalysisStore()

		_navigation = State(initialValue: navigation)
		_catalog = State(initialValue: catalog)
		_boardStore = State(initialValue: boardStore)
		_scratchpadStore = State(initialValue: scratchpadStore)
		_translationAccount = State(initialValue: translationAccount)
		_analysisStore = State(initialValue: analysisStore)
		let sync = SyncController(account: translationAccount, boardStore: boardStore, scratchpadStore: scratchpadStore, catalog: catalog, analysis: analysisStore)
		_sync = State(initialValue: sync)

		let purchases = PurchaseStore(account: translationAccount)
		_purchases = State(initialValue: purchases)

		let askStore = AskStore()
		askStore.boardStore = boardStore
		_askStore = State(initialValue: askStore)

		AskIntents.prepare()

		AppDelegate.sync = sync
		AppDelegate.navigation = navigation
		AppDelegate.boardStore = boardStore

		unsafe AppDependencyManager.shared.add(
			dependency: navigation
		)

		unsafe AppDependencyManager.shared.add(
			dependency: catalog
		)
	}

	var body: some Scene {
		WindowGroup {
			AppScene()
				.environment(catalog)
				.environment(navigation)
				.environment(boardStore)
				.environment(scratchpadStore)
				.environment(askStore)
				.environment(analysisStore)
				.environment(translationAccount)
				.environment(purchases)
				.environment(sync)
				.task {
					await sync.run()
				}
				.onChange(of: translationAccount.signedIn) {
					// Also signed out when translation finds the server forgot the token
					sync.accountChanged()
					Task {
						await translationAccount.refreshUsage()
						await purchases.uploadCurrent()
					}
				}
				// Universal links arrive here too
				.onOpenURL { url in
					if let token = BoardInviteLink.token(from: url) {
						navigation.presentSheet(.joinBoard(token))
					} else if let entry = ItemOfTheDayItem.entry(from: url) {
						navigation.openLibraryEntry(category: entry.category, id: entry.id)
					} else if let board = DeepResearchAttributes.board(from: url) {
						navigation.openAnalysis(of: board, in: boardStore)
					} else {
						receiveShared()
					}
				}
				.task {
					StatusBadgeWindow.install()
					AppUpdateWarning.shared.start()
					navigation.startup()
					// Answers and breakdowns the server carried on with while the app was closed
					askStore.resumeInterrupted(account: translationAccount)
					navigation.resumeBreakDown()
					receiveShared()
					purchases.start()
					await translationAccount.refreshUsage()

					do {
						try await catalog.load()
						try await LibraryIndexer.indexIfNeeded(from: catalog)
					} catch {
						print("Library indexing failed: \(error)")
					}
				}
		}
		.onChange(of: scenePhase) { _, phase in
			// Saves usually wait for a pause in typing, don't lose that pause to the app closing
			if phase != .active {
				boardStore.save()
				askStore.save()
				scratchpadStore.save()
			} else {
				// The extension can't always open the app, so whatever it left is picked up on the way back in
				receiveShared()
				askStore.resumeInterrupted(account: translationAccount)
			}
			sync.scenePhaseChanged(phase)
		}
	}

	private func receiveShared() {
		guard let item = SharedItemInbox.shared?.take() else { return }

		if item.action == .ask, case let .text(text) = item.content {
			navigation.presentSheet(.addToChat(.text(text)))
		} else {
			navigation.presentSheet(.shared(item))
		}
	}
}

struct AppScene: View {
	var body: some View {
		ContentView()
	}
}
