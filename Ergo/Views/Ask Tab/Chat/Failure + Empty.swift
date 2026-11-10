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

	/// Asking again won't help until tomorrow, or until there's more to spend
	private var needsPlan: Bool {
		code == .allowanceUsed || code == .planRequired
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
			} else if needsPlan {
				Button("See Ergo Plus", systemImage: "sparkles") {
					navigation.presentSheet(.plus)
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
	let mode: AskMode
	let isAboutBoard: Bool
	let pick: (String) -> Void

	private var starters: [String] {
		if isAboutBoard {
			return ["What's the weakest step here?", "What's the strongest objection?", "What's this argument missing?"]
		}
		return switch mode {
			case .normal: ["Is there a fallacy in this argument?", "What's the difference between valid and sound?", "Which biases affect how we judge evidence?"]
			case .debate: ["Free will is an illusion.", "Morality is just opinion.", "We should never lie."]
			case .scout: []
		}
	}

	private var title: String {
		isAboutBoard ? "Ask About This Board" : mode == .normal ? "Ask" : mode.name
	}

	private var description: String {
		isAboutBoard ? "Ask about the argument, or ask for changes. Anything it changes can be undone." : mode.blurb
	}

	var body: some View {
		VStack(spacing: 20) {
			ContentUnavailableView(title, systemImage: isAboutBoard ? "sparkles" : mode.symbol, description: Text(description))
				.fixedSize(horizontal: false, vertical: true)

			VStack(spacing: 8) {
				ForEach(starters, id: \.self) { starter in
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
