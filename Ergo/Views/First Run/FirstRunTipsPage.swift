//
//  FirstRunTipsPage.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import SwiftUI

/// Only what someone wouldn't find by looking
struct FirstRunTipsPage: View {
	let next: () -> Void

	var body: some View {
		FirstRunPage {
			Text("A Few Things to Know")
				.font(.largeTitle.bold())

			FirstRunRow(title: "Tap Board Again", symbol: "rectangle.stack", detail: "Tapping the Board tab while you're on it shows all your boards.")
			FirstRunRow(title: "Drag to Connect", symbol: "arrow.up.and.down", detail: "Select a card, then drag the handle above or below it onto another card. Let go on empty space to make a new card there.")
			FirstRunRow(title: "Hold for Modes", symbol: "plus.circle", detail: "In Ask, holding + starts a chat in a different mode, like a debate.")
			FirstRunRow(title: "Share Into Ergo", symbol: "square.and.arrow.up", detail: "Share a web page or some text to Ergo from any app to break it down or ask about it.")
		} buttons: {
			Button(action: next) {
				Text("Continue")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.glassProminent)
		}
	}
}

#Preview {
	FirstRunTipsPage {}
}
