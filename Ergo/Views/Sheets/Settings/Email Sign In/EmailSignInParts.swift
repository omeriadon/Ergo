//
//  EmailSignInParts.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoProtocol
import SwiftUI

/// What's wrong with the shape of the email or password, before anything is sent
struct ShapeIssues: View {
	let issues: [String]

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			ForEach(issues, id: \.self) { issue in
				Text(issue)
					.foregroundStyle(.red)
			}
		}
	}
}

// MARK: - Parts

struct EmailModePicker: View {
	@Binding var mode: EmailSignInView.Mode

	var body: some View {
		Section {
			Picker("Mode", selection: $mode) {
				Text("Sign In")
					.tag(EmailSignInView.Mode.signIn)
				Text("Create Account")
					.tag(EmailSignInView.Mode.createAccount)
			}
			.pickerStyle(.segmented)
			.listRowBackground(Color.clear)
			.listRowInsets(EdgeInsets())
			.accessibilityIdentifier("email.mode")
		}
	}
}

struct EmailFields: View {
	@Binding var email: String
	@Binding var password: String
	let mode: EmailSignInView.Mode
	var focus: FocusState<EmailSignInView.Field?>.Binding
	let issues: [String]
	let submit: () -> Void

	var body: some View {
		Section {
			TextField("Email", text: $email)
				.keyboardType(.emailAddress)
				.textContentType(.username)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused(focus, equals: .email)
				.submitLabel(.next)
				.onSubmit { focus.wrappedValue = .password }
				.accessibilityIdentifier("email.address")

			SecureField("Password", text: $password)
				.textContentType(mode == .createAccount ? .newPassword : .password)
				.focused(focus, equals: .password)
				.submitLabel(.go)
				.onSubmit(submit)
				.accessibilityIdentifier("email.password")
				// A new field, so iOS looks at its content type again and offers a strong password
				.id(mode)
		} footer: {
			ShapeIssues(issues: issues)
		}
	}
}

struct EmailSubmitFooter: View {
	let problem: ServiceError?
	let explanation: String
	let offersSignIn: Bool
	let signInInstead: () -> Void

	var body: some View {
		if let problem {
			VStack(alignment: .leading, spacing: 6) {
				Text(problem.message)
					.foregroundStyle(.red)

				// Signed in already, signing in to another account would be refused
				if problem.code == .emailInUse, offersSignIn {
					Button("Sign In Instead", action: signInInstead)
						.font(.footnote.weight(.semibold))
						.accessibilityIdentifier("email.signInInstead")
				}
			}
		} else {
			Text(explanation)
		}
	}
}
