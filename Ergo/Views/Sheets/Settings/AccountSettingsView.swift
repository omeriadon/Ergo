//
//  AccountSettingsView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AuthenticationServices
import Defaults
import SwiftUI

/// The Account page of Settings: signing in with Apple or an email, and how sync is doing
struct AccountSettingsView: View {
	@Environment(SyncController.self)
	private var sync

	// Release builds never read these two, but views watch them so a debug build follows a switch
	@Default(.serverEnvironment) var serverEnvironment
	@Default(.translationServer) var translationServer

	@State private var problem: String?

	private var hasServer: Bool {
		ServerEnvironment.effective(serverEnvironment, macAddress: translationServer) != nil
	}

	var body: some View {
		List {
			Section {
				if sync.isSignedIn {
					SignedInRows(problem: $problem)
				} else {
					Group {
						SignInRow(problem: $problem)

						NavigationLink("Sign in with Email") {
							EmailSignInView()
						}
						.accessibilityIdentifier("account.emailSignIn")
					}
					.disabled(!hasServer)
				}
			} footer: {
				AccountFooter(problem: problem, hasServer: hasServer)
			}
		}
		.toolbarTitleVire("Account", "person.crop.circle")
	}
}

// MARK: - Signed out

private struct SignInRow: View {
	@Environment(SyncController.self)
	private var sync

	@Environment(\.colorScheme)
	private var colorScheme

	@Binding var problem: String?

	var label = SignInWithAppleButton.Label.signIn

	@State private var attempt = AppleSignIn()

	var body: some View {
		SignInWithAppleButton(label) { request in
			attempt = AppleSignIn()
			attempt.prepare(request)
		} onCompletion: { result in
			signIn(result, nonce: attempt.nonce)
		}
		.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
		.frame(maxWidth: .infinity, minHeight: 44)
		.accessibilityIdentifier("account.signIn")
	}

	private func signIn(_ result: Result<ASAuthorization, Error>, nonce: String) {
		Task {
			do {
				guard let token = try AppleSignIn.identityToken(from: result) else { return }
				try await sync.signIn(identityToken: token, nonce: nonce)
				problem = nil
			} catch {
				problem = error.localizedDescription
			}
		}
	}
}

// MARK: - Signed in

private struct SignedInRows: View {
	@Environment(SyncController.self)
	private var sync

	@Binding var problem: String?

	@State private var confirmingSignOut = false
	@State private var confirmingDelete = false

	var body: some View {
		// Apple doesn't share the email, so it's only known when this device used one
		if let email = sync.email {
			LabeledContent("Email", value: email)
		} else {
			Text("Signed in")
		}

		LabeledContent("Sync") {
			SyncStatusText(status: sync.status)
		}
		.accessibilityIdentifier("account.syncStatus")

		EmailLink(hasEmail: sync.email != nil)

		if sync.canAddApple {
			SignInRow(problem: $problem, label: .continue)
		}

		Button("Sign Out") {
			confirmingSignOut = true
		}
		.accessibilityIdentifier("account.signOut")
		.confirmationDialog("Sign out?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
			Button("Sign Out", role: .destructive) {
				leave { try await sync.signOut() }
			}
		} message: {
			Text("Your pages stay on this iPhone")
		}

		Button("Delete Account", role: .destructive) {
			confirmingDelete = true
		}
		.accessibilityIdentifier("account.delete")
		.confirmationDialog("Delete account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
			Button("Delete Account", role: .destructive) {
				leave { try await sync.deleteAccount() }
			}
		} message: {
			Text("Deletes everything Ergo's server keeps for you, including your Claude and ChatGPT connections. Pages on this iPhone stay")
		}
	}

	private func leave(_ work: @escaping () async throws -> Void) {
		Task {
			do {
				try await work()
				problem = nil
			} catch {
				problem = error.localizedDescription
			}
		}
	}
}

/// Changing the password needs an email this device knows about. Without one, an email can be added.
private struct EmailLink: View {
	let hasEmail: Bool

	var body: some View {
		if hasEmail {
			NavigationLink("Change Password") {
				ChangePasswordView()
			}
			.accessibilityIdentifier("account.changePassword")
		} else {
			NavigationLink("Add Email and Password") {
				EmailSignInView(isAddingEmail: true)
			}
			.accessibilityIdentifier("account.addEmail")
		}
	}
}

private struct SyncStatusText: View {
	let status: SyncController.Status

	var body: some View {
		switch status {
			case .notSynced:
				Text("Not synced yet")
			case .syncing:
				Text("Syncing")
			case let .upToDate(date):
				TimelineView(.everyMinute) { _ in
					Text("Up to date · \(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))")
				}
			case .waitingForNetwork:
				Text("Waiting for network")
			case let .failed(message):
				Text(message)
					.foregroundStyle(.red)
		}
	}
}

// MARK: - Footer

private struct AccountFooter: View {
	@Environment(SyncController.self)
	private var sync

	let problem: String?
	let hasServer: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			if let problem {
				Text(problem)
					.foregroundStyle(.red)
			}

			ForEach(sync.oversizedPages, id: \.self) { title in
				Text("Page '\(title)' is too large to sync")
					.foregroundStyle(.red)
			}

			if !hasServer {
				Text("Set the Mac's address in Translation → Server to sign in.")
			} else if !sync.isSignedIn {
				Text("Sync pages, bookmarks and letters across your devices. Translation works without an account.")
			} else if sync.canAddApple {
				Text("Continue with Apple to sign in with either your Apple ID or this email.")
			}
		}
	}
}

// MARK: - Previews

#Preview("Signed out") {
	Form {
		AccountSettingsView()
	}
	.environment(SyncController.preview(signedIn: false))
}

#Preview("Signed in") {
	Form {
		AccountSettingsView()
	}
	.environment(SyncController.preview(signedIn: true, status: .upToDate(.now.addingTimeInterval(-120))))
}

#Preview("Signed in with email") {
	NavigationStack {
		AccountSettingsView()
	}
	.environment(SyncController.preview(signedIn: true, email: "ada@example.com", status: .syncing))
}
