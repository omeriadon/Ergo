//
//  SettingsView.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import Defaults
import SwiftUI

struct SettingsView: View {
	@Environment(NavigationManager.self)
	private var navigation

	// Release builds never read these two, but views watch them so a debug build follows a switch
	@Default(.serverEnvironment) var serverEnvironment
	@Default(.translationServer) var translationServer
	@Default(.translationProvider) var translationProvider

	@Environment(TranslationAccount.self)
	private var account

	var body: some View {
		NavigationStack {
			Form {
				NavigationLink {
					UISettingsView()
				} label: {
					Label("UI", systemImage: "app.background.dotted")
				}

				NavigationLink {
					WidgetsSettingsView()
				} label: {
					Label("Widgets", systemImage: "widget.small")
				}

				Section {
					NavigationLink {
						AccountSettingsView()
					} label: {
						Label("Account", systemImage: "person.crop.circle")
					}
				}

				Section {
					NavigationLink {
						TranslationSettingsView()
					} label: {
						LabeledContent {
							Text(translationValue)
						} label: {
							Label("AI", systemImage: "sparkles")
						}
					}
					.accessibilityIdentifier("settings.translation")
				}

				Section {
					NavigationLink {
						AboutView()
					} label: {
						Label("About Ergo", image: "Ergo")
					}
				}
			}
			.tint(.accent)
			.toolbarTitleVire("Settings", "gearshape")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .close) {
						navigation.dismissSheet()
					}
				}
			}
		}
	}

	/// Without asking the server: "Not connected" only once it's known, otherwise the provider that'll be used
	private var translationValue: String {
		if ServerEnvironment.effective(serverEnvironment, macAddress: translationServer) == nil {
			return "Not set up"
		}
		return account.isConnected(translationProvider) == false ? "Not connected" : translationProvider.name
	}
}

#Preview {
	SettingsView()
		.environment(NavigationManager())
		.environment(TranslationAccount())
		.environment(SyncController.preview(signedIn: false))
}
