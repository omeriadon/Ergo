//
//  ErgoApp.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import AppIntents
import CoreSpotlight
import SwiftUI

@main
struct ErgoApp: App {
	@State private var navigation = NavigationManager()
	@State private var catalog = CatalogStore()
	@State private var pageStore: PageStore
	@State private var translationAccount: TranslationAccount
	@State private var sync: SyncController

	@Environment(\.scenePhase)
	private var scenePhase

	init() {
		let navigation = NavigationManager()
		let catalog = CatalogStore()
		let pageStore = PageStore()
		let translationAccount = TranslationAccount()

		_navigation = State(initialValue: navigation)
		_catalog = State(initialValue: catalog)
		_pageStore = State(initialValue: pageStore)
		_translationAccount = State(initialValue: translationAccount)
		_sync = State(initialValue: SyncController(account: translationAccount, pageStore: pageStore, catalog: catalog))

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
				.environment(pageStore)
				.environment(translationAccount)
				.environment(sync)
				.task {
					await sync.run()
				}
				.onChange(of: translationAccount.signedIn) {
					// Also signed out when translation finds the server forgot the token
					sync.accountChanged()
				}
				.task {
					navigation.startup()

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
				pageStore.save()
			}
			sync.scenePhaseChanged(phase)
		}
	}
}

struct AppScene: View {
	var body: some View {
		ContentView()
	}
}
