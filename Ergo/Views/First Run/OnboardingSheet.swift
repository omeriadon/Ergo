//
//  OnboardingSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import SwiftUI

/// What a new install sees first, as a sheet over the app: what Ergo is, what isn't obvious, and permission to send text
/// to AI. Each page pushes the next, and it can't be swiped away: only the privacy page finishes it, so nobody gets past
/// without choosing. `NavigationManager.needsOnboarding` keeps it on screen, and other sheets wait behind it.
struct OnboardingSheet: View {
	@State private var path: [Page] = []

	enum Page: Hashable {
		case tips, privacy
	}

	var body: some View {
		NavigationStack(path: $path) {
			FirstRunIntroPage {
				path.append(.tips)
			}
			.navigationDestination(for: Page.self) { page in
				switch page {
					case .tips:
						FirstRunTipsPage {
							path.append(.privacy)
						}

					case .privacy:
						FirstRunPrivacyPage()
				}
			}
		}
		.interactiveDismissDisabled()
		.presentationDetents([.large])
		.fontDesign(.rounded)
	}
}

/// A page's scrolling content, with its buttons kept at the bottom
struct FirstRunPage<Content: View, Buttons: View>: View {
	@ViewBuilder let content: Content
	@ViewBuilder let buttons: Buttons

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				content
			}
			.padding(.horizontal, 24)
			.padding(.top, 8)
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
			.padding(.bottom, 16)
			.frame(maxWidth: 560)
		}
		.toolbarTitleDisplayMode(.inline)
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
	Color.clear
		.sheet(isPresented: .constant(true)) {
			OnboardingSheet()
		}
}
