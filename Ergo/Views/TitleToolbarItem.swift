//
//  TitleToolbarItem.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

extension View {
	func toolbarTitleItem() -> some View {
		modifier(ToolbarTitleItemModifier())
	}
}

private struct ToolbarTitleItemModifier: ViewModifier {
	@Environment(NavigationManager.self) private var navigation

	func body(content: Content) -> some View {
		content
			.toolbar {
				ToolbarTitleItem(
					openSettings: {
						navigation.presentSheet(.settings(id: "3refd"))
					},
					openAbout: {
						navigation.presentSheet(.about(id: "3refd"))
					}
				)
			}
	}
}

struct ToolbarTitleItem: ToolbarContent {

	let openSettings: () -> Void
	let openAbout: () -> Void


	var body: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {

			Menu {
				Button {
					openSettings()
				} label: {
					Label("Settings", systemImage: "gearshape")

				}

				Button {
					openAbout()
				} label: {
					Label("About", systemImage: "info")
				}

			} label: {
				ToolbarTitleView()
			}
		}
		.visibilityPriority(.high)
		.sharedBackgroundVisibility(.hidden)
	}
}

struct ToolbarTitleView: View {
	var body: some View {
		Image("Ergo")
			.foregroundStyle(.accent)
	}
}
