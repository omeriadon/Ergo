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

	init() {
		let navigation = NavigationManager()
		let catalog = CatalogStore()

		_navigation = State(initialValue: navigation)
		_catalog = State(initialValue: catalog)

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
				.task {
					navigation.startup()

					do {
						try await LibraryIndexer.indexIfNeeded(from: catalog)
					} catch {
						print("Library indexing failed: \(error)")
					}
				}
		}
	}
}

struct AppScene: View {
	var body: some View {
		ContentView()
	}
}
