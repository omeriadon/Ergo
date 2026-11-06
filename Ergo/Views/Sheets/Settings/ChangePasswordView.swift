//
//  ChangePasswordView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import SwiftUI

/// Changes the password of an account this device knows has an email. Every other device is signed out.
struct ChangePasswordView: View {
	@Environment(SyncController.self)
	private var sync

	@Environment(\.dismiss)
	private var dismiss

	/// Both only held until they're sent
	@State private var current = ""
	@State private var new = ""

	/// Shown once the new password's been typed and left, or sent
	@State private var checksNew = false
	@FocusState private var isEditingNew: Bool

	@State private var isSending = false
	@State private var problem: String?

	var body: some View {
		Form {
			fields
			submitSection
		}
		.navigationTitle("Change Password")
		.animation(.smooth, value: problem)
		.animation(.smooth, value: checksNew)
		.onChange(of: isEditingNew) { wasEditing, _ in
			if wasEditing, !new.isEmpty {
				checksNew = true
			}
		}
	}

	private var fields: some View {
		Section {
			SecureField("Current Password", text: $current)
				.textContentType(.password)

			SecureField("New Password", text: $new)
				.textContentType(.newPassword)
				.focused($isEditingNew)
				.onSubmit(submit)
		} footer: {
			if checksNew, let issue = EmailSignInView.passwordIssue(new) {
				Text(issue)
					.foregroundStyle(.red)
			}
		}
	}

	private var submitSection: some View {
		Section {
			Button(action: submit) {
				HStack {
					Text("Change Password")
					if isSending {
						Spacer()
						ProgressView()
					}
				}
			}
			.disabled(current.isEmpty || new.isEmpty || isSending)
			.accessibilityIdentifier("account.changePassword.submit")
		} footer: {
			if let problem {
				Text(problem)
					.foregroundStyle(.red)
			} else {
				Text("Other devices signed in to this account are signed out. This iPhone stays signed in.")
			}
		}
	}

	private func submit() {
		guard !current.isEmpty, !new.isEmpty, !isSending else { return }
		checksNew = true
		guard EmailSignInView.passwordIssue(new) == nil else { return }

		let (current, new) = (current, new)
		self.current = ""
		self.new = ""
		checksNew = false
		isSending = true
		problem = nil

		Task {
			defer { isSending = false }
			do {
				try await sync.changePassword(current: current, new: new)
				dismiss()
			} catch is CancellationError {
			} catch {
				problem = error.localizedDescription
			}
		}
	}
}

#Preview {
	NavigationStack {
		ChangePasswordView()
	}
	.environment(SyncController.preview(signedIn: true, email: "ada@example.com"))
}
