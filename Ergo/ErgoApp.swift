//
//  ErgoApp.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

@main
struct ErgoApp: App {
	var body: some Scene {
		WindowGroup {
			AppScene()
		}
	}
}

struct AppScene: View {
	@State private var navigation = NavigationManager()
	@State private var catalog = CatalogStore()

	var body: some View {
		ContentView()
			.environment(catalog)
			.environment(navigation)
			.task {
				try? await catalog.load()
			}
	}
}
