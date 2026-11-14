//
//  FirstRunPrivacyPage.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import Defaults
import SwiftUI

/// Permission to send text to AI, asked before any is sent. This is legal text, so it names every provider, OpenRouter
/// included; nowhere else in the app does. Either answer finishes the first run.
struct FirstRunPrivacyPage: View {
	var body: some View {
		FirstRunPage {
			Text("Your Privacy")
				.font(.largeTitle.bold())

			Text("Without an account, what you make stays on this device. Ask, Break Down and Deep Research are different: they send what you give them, like a question, a board or a shared page, to an AI model. Which company receives it depends on the model you pick in Settings → AI:")

			VStack(alignment: .leading, spacing: 12) {
				FirstRunRow(title: "Ergo's Model", symbol: "sparkles", detail: "Sent through OpenRouter, which passes it to the company hosting the model.")
				FirstRunRow(title: "Your Claude Login", symbol: "person.crop.circle", detail: "Sent to Anthropic, under your own account with them.")
				FirstRunRow(title: "Your ChatGPT Login", symbol: "person.crop.circle", detail: "Sent to OpenAI, under your own account with them.")
			}

			Text("They never receive your email address, your name or your Ergo account. You can change your answer in Settings → AI.")
				.foregroundStyle(.secondary)

			LegalLinks()
		} buttons: {
			FirstRunConsentButtons()
		}
	}
}

/// The privacy policy and terms, as links to the server's pages
struct LegalLinks: View {
	var body: some View {
		HStack(spacing: 20) {
			SwiftUI.Link("Privacy Policy", destination: ServerEnvironment.privacyPolicyURL)
			SwiftUI.Link("Terms of Use", destination: ServerEnvironment.termsURL)
		}
		.font(.subheadline)
	}
}

private struct FirstRunConsentButtons: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		Button {
			finish(allowingAI: true)
		} label: {
			Text("Allow AI Features")
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.glassProminent)
		.accessibilityIdentifier("firstRun.allow")

		Button {
			finish(allowingAI: false)
		} label: {
			Text("Not Now")
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.glass)
		.accessibilityIdentifier("firstRun.decline")
	}

	private func finish(allowingAI: Bool) {
		Defaults[.aiConsent] = allowingAI
		navigation.finishOnboarding()
	}
}

#Preview {
	NavigationStack {
		FirstRunPrivacyPage()
	}
	.environment(NavigationManager())
}
