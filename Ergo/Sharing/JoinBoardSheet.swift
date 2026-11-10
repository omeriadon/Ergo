//
//  JoinBoardSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import Defaults
import ErgoProtocol
import SwiftUI

/// What opening an invite link shows: whose board it is, what you'd be able to do, and a name to join with.
/// Having the link is what lets someone in, so there's nothing else to ask.
struct JoinBoardSheet: View {
	private enum Phase {
		case loading
		case failed(String)
		case ready(BoardInvitePreview)
	}

	/// Never logged or shown: anyone with it can join
	let token: String

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(SyncController.self)
	private var sync

	@State private var phase = Phase.loading
	@State private var attempt = 0

	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Join Board")
				.toolbarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						Button(role: .cancel) {
							navigation.dismissSheet()
						}
						.accessibilityIdentifier("join.cancel")
					}
				}
		}
		.task(id: attempt) {
			await load()
		}
	}

	@ViewBuilder
	private var content: some View {
		switch phase {
			case .loading:
				ProgressView("Opening Invite")

			case let .failed(message):
				ContentUnavailableView {
					Label("Couldn't Open Invite", systemImage: "exclamationmark.triangle")
				} description: {
					Text(message)
				} actions: {
					Button("Try Again", systemImage: "arrow.clockwise") {
						phase = .loading
						attempt += 1
					}
					.buttonStyle(.glass)
					.accessibilityIdentifier("join.tryAgain")
				}

			case let .ready(preview):
				JoinBoardForm(preview: preview, join: join)
		}
	}

	private func load() async {
		do {
			let preview = try await sync.previewInvite(token: token)
			guard !Task.isCancelled else { return }
			phase = .ready(preview)
		} catch {
			guard !Task.isCancelled, !(error is CancellationError) else { return }
			phase = .failed(error.sharingMessage)
		}
	}

	/// Throws so the form can say what went wrong and stay up
	private func join(name: String) async throws {
		try await sync.join(token: token, name: name)
		navigation.reveal(.board)
		sync.askToNotify()
	}
}

// MARK: - Form

private struct JoinBoardForm: View {
	let preview: BoardInvitePreview
	let join: (String) async throws -> Void

	@Environment(SyncController.self)
	private var sync

	@Default(.sharingName) private var name

	@State private var isJoining = false
	@State private var problem: String?

	var body: some View {
		Form {
			details

			if sync.isSignedIn {
				nameSection
				joinSection
			} else {
				signInSection
			}
		}
		.animation(.smooth, value: problem)
		.animation(.smooth, value: sync.isSignedIn)
	}

	private var details: some View {
		Section {
			VStack(alignment: .leading, spacing: 4) {
				Text(preview.title)
					.font(.headline)

				Text("Shared by \(preview.ownerName)")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier("join.title")

			LabeledContent("You'll be able to", value: preview.role == .viewer ? "View it" : "Edit it")
				.accessibilityIdentifier("join.role")

			LabeledContent("People", value: preview.memberCount, format: .number)
		}
	}

	/// The same controls as Settings
	private var signInSection: some View {
		Section {
			SignInRow(problem: $problem)

			NavigationLink("Sign in with Email") {
				EmailSignInView()
			}
			.accessibilityIdentifier("join.emailSignIn")
		} footer: {
			if let problem {
				Text(problem)
					.foregroundStyle(.red)
			} else {
				Text("Shared boards sync through your account, so joining needs one.")
			}
		}
	}

	private var nameSection: some View {
		Section {
			TextField("Your name", text: $name)
				.textContentType(.name)
				.submitLabel(.done)
				.accessibilityIdentifier("join.name")
		} footer: {
			if let issue = SharingName.problem(with: name) {
				Text(issue)
					.foregroundStyle(.red)
			} else {
				Text("Other people on this board see this name.")
			}
		}
	}

	private var joinSection: some View {
		Section {
			Button(action: submit) {
				HStack {
					Text("Join")
					if isJoining {
						Spacer()
						ProgressView()
					}
				}
			}
			.disabled(isJoining || !SharingName.isValid(name))
			.accessibilityIdentifier("join.submit")
		} footer: {
			if let problem {
				Text(problem)
					.foregroundStyle(.red)
			}
		}
	}

	private func submit() {
		isJoining = true
		problem = nil
		Task {
			defer { isJoining = false }
			do {
				try await join(name)
			} catch {
				problem = error.sharingMessage
			}
		}
	}
}

// MARK: - Previews

private let previewInvite = BoardInvitePreview(board: "", title: "All men are mortal", ownerName: "Sam", role: .editor, memberCount: 3)

#Preview("Signed in") {
	NavigationStack {
		JoinBoardForm(preview: previewInvite, join: { _ in })
	}
	.environment(SyncController.preview(signedIn: true))
}

#Preview("Signed out") {
	NavigationStack {
		JoinBoardForm(preview: previewInvite, join: { _ in })
	}
	.environment(SyncController.preview(signedIn: false))
}
