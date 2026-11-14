//
//  FirstRunView.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import Defaults
import SwiftUI

/// What a new install sees in place of the tabs: what Ergo is, what isn't obvious, and permission to send text to AI.
/// Swiping can skip ahead, but only the privacy page finishes it, so nobody gets past without choosing.
struct FirstRunView: View {
	@State private var page = Page.intro

	enum Page: Hashable {
		case intro, tips, privacy
	}

	var body: some View {
		TabView(selection: $page.animation()) {
			FirstRunIntroPage {
				page = .tips
			}
			.tag(Page.intro)

			FirstRunTipsPage {
				page = .privacy
			}
			.tag(Page.tips)

			FirstRunPrivacyPage()
				.tag(Page.privacy)
		}
		.tabViewStyle(.page(indexDisplayMode: .always))
		.indexViewStyle(.page(backgroundDisplayMode: .always))
		.fontDesign(.rounded)
	}
}

/// A page's scrolling content, with its buttons kept above the page dots
struct FirstRunPage<Content: View, Buttons: View>: View {
	@ViewBuilder let content: Content
	@ViewBuilder let buttons: Buttons

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				content
			}
			.padding(.horizontal, 24)
			.padding(.top, 48)
			.frame(maxWidth: 560, alignment: .leading)
			.frame(maxWidth: .infinity)
		}
		.scrollBounceBehavior(.basedOnSize)
		.safeAreaInset(edge: .bottom) {
			VStack(spacing: 12) {
				buttons
			}
			.controlSize(.large)
			.padding(.horizontal, 24)
			.padding(.bottom, 56)
			.frame(maxWidth: 560)
		}
	}
}

/// A symbol beside a heading and a line under it, for the intro and the tips
struct FirstRunRow: View {
	let title: LocalizedStringKey
	let symbol: String
	let detail: LocalizedStringKey

	var body: some View {
		Label {
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.headline)
				Text(detail)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		} icon: {
			Image(systemName: symbol)
				.font(.title2)
				.foregroundStyle(.accent)
				.frame(width: 36)
		}
	}
}

// MARK: - Intro

private struct FirstRunIntroPage: View {
	let next: () -> Void

	var body: some View {
		FirstRunPage {
			VStack(alignment: .leading, spacing: 8) {
				ErgoIcon(size: 120)
				Text("Welcome to Ergo")
					.font(.largeTitle.bold())
				Text("Pull the arguments out of what you read, check their logic, and learn the ideas behind good reasoning.")
					.foregroundStyle(.secondary)
			}

			FirstRunRow(title: "Board", symbol: "flowchart", detail: "Lay out an argument as cards and arrows, or break down an article into one.")
			FirstRunRow(title: "Logic", symbol: "function", detail: "Write an argument in logic, read it back in English, and check whether it's valid.")
			FirstRunRow(title: "Ask", symbol: "bubble.left.and.text.bubble.right", detail: "Ask about reasoning, debate a claim, or ask about a board.")
			FirstRunRow(title: "Library", symbol: "books.vertical", detail: "Fallacies, biases, paradoxes and more, with the logic course.")
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
	FirstRunView()
}
