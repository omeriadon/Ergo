//
//  ErgoApp.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import AppIntents
import CoreSpotlight
import ErgoShare
import SwiftUI

@main
struct ErgoApp: App {
	@State private var navigation = NavigationManager()
	@State private var catalog = CatalogStore()
	@State private var boardStore: BoardStore
	@State private var scratchpadStore: ScratchpadStore
	@State private var askStore = AskStore()
	@State private var translationAccount: TranslationAccount
	@State private var sync: SyncController

	@Environment(\.scenePhase)
	private var scenePhase

	init() {
		let navigation = NavigationManager()
		let catalog = CatalogStore()
		let boardStore = BoardStore()
		let scratchpadStore = ScratchpadStore()
		let translationAccount = TranslationAccount()

		_navigation = State(initialValue: navigation)
		_catalog = State(initialValue: catalog)
		_boardStore = State(initialValue: boardStore)
		_scratchpadStore = State(initialValue: scratchpadStore)
		_translationAccount = State(initialValue: translationAccount)
		_sync = State(initialValue: SyncController(account: translationAccount, boardStore: boardStore, scratchpadStore: scratchpadStore, catalog: catalog))

		AppDependencyManager.shared.add(
			dependency: navigation
		)

		AppDependencyManager.shared.add(
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
				.environment(translationAccount)
				.environment(sync)
				.task {
					await sync.run()
				}
				.onChange(of: translationAccount.signedIn) {
					// Also signed out when translation finds the server forgot the token
					sync.accountChanged()
				}
				.onOpenURL { _ in
					receiveShared()
				}
				.task {
					navigation.startup()
					receiveShared()

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
			}
			sync.scenePhaseChanged(phase)
		}
	}

	private func receiveShared() {
		guard let item = SharedItemInbox.shared?.take() else { return }

		if item.action == .ask, case let .text(text) = item.content {
			askStore.startChat(with: text)
			navigation.dismissSheet()
			navigation.selectedTab = .ask
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
