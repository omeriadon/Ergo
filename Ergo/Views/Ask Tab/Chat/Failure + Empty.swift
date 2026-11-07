//
//  Failure + Empty.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import SwiftUI

struct AskFailureRow: View {
	let message: String
	let code: ServiceError.Code
	let retry: () -> Void

	@Environment(NavigationManager.self)
	private var navigation

	/// Only for errors fixed by connecting a provider in Settings
	private var needsSetUp: Bool {
		code == .notConnected || code == .credentialRejected
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Label(message, systemImage: "xmark.circle.fill")
				.font(.subheadline)
				.foregroundStyle(.red)

			if needsSetUp {
				Button("Set Up") {
					navigation.presentSheet(.settings(id: "3refd"))
				}
				.buttonStyle(.glass)
			} else {
				Button("Try Again", systemImage: "arrow.clockwise", action: retry)
					.buttonStyle(.glass)
			}
		}
		.accessibilityIdentifier("ask.failure")
	}
}

struct AskEmptyView: View {
	private static let starters = [
		"Is there a fallacy in this argument?",
		"What's the difference between valid and sound?",
		"Which biases affect how we judge evidence?",
	]

	let pick: (String) -> Void

	var body: some View {
		VStack(spacing: 20) {
			ContentUnavailableView(
				"Ask",
				systemImage: "bubble.left.and.text.bubble.right",
				description: Text("Paste an argument or ask a question. Answers cite Ergo's library.")
			)
			.fixedSize(horizontal: false, vertical: true)

			VStack(spacing: 8) {
				ForEach(Self.starters, id: \.self) { starter in
					Button(starter) {
						pick(starter)
					}
					.buttonStyle(.glass)
				}
			}
		}
		.padding(16)
	}
}
