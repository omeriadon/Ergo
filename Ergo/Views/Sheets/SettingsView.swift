//
//  SettingsView.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import Defaults
import ErgoLogic
import ErgoProtocol
import SwiftUI

struct SettingsView: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Default(.ditherEnabled) var ditherEnabled
	@Default(.logicLetters) var logicLetters
	// Release builds never read these two, but views watch them so a debug build follows a switch
	@Default(.serverEnvironment) var serverEnvironment
	@Default(.translationServer) var translationServer
	@Default(.translationProvider) var translationProvider

	@Environment(TranslationAccount.self)
	private var account

	var body: some View {
		NavigationStack {
			Form {
				Section {
					Toggle("Dither", isOn: $ditherEnabled)
				} footer: {
					Text("The animated backgrounds behind detail pages and Check. Turning this off removes them entirely.")
				}

				Section {
					NavigationLink {
						LogicLettersView()
					} label: {
						LabeledContent("Logic Letters") {
							Text(LogicLetters.resolved(logicLetters).joined(separator: " "))
								.monospaced()
						}
					}
				}

				AccountSettingsView()

				Section {
					NavigationLink {
						TranslationSettingsView()
					} label: {
						LabeledContent("Translation") {
							Text(translationValue)
						}
					}
					.accessibilityIdentifier("settings.translation")
				}
			}
			.navigationTitle("Settings")
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
