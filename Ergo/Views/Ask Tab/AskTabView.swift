//
//  AskTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// A placeholder until the Ask tab has something to ask.
struct AskTabView: View {
	var body: some View {
		ContentUnavailableView(
			"Ask",
			systemImage: "bubble.left.and.text.bubble.right",
			description: Text("Questions about arguments will live here.")
		)
	}
}

#Preview {
	NavigationStack {
		AskTabView()
	}
}
