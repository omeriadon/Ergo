//
//  EmailSignInView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import SwiftUI

/// Signs in with an email and password, or creates an account with them.
/// Signed in already, it only creates, which adds the email to the account.
struct EmailSignInView: View {
	enum Mode: Hashable {
		case signIn
		case createAccount
	}

	enum Field: Hashable {
		case email
		case password
	}

	@Environment(SyncController.self)
	private var sync

	@Environment(\.dismiss)
	private var dismiss

	@State private var mode: Mode

	/// Signed in with Apple, so there's no account to sign in to, only an email to add
	private let isAddingEmail: Bool

	@State private var email = ""

	/// Only held until it's sent. Saving it is the system password manager's job.
	@State private var password = ""

	/// Fields whose shape is shown, once they've been typed in and left, or sent
	@State private var checked: Set<Field> = []
	@FocusState private var focus: Field?

	@State private var isSending = false
	@State private var problem: ServiceError?

	init(mode: Mode = .signIn, isAddingEmail: Bool = false) {
		_mode = State(initialValue: isAddingEmail ? .createAccount : mode)
		self.isAddingEmail = isAddingEmail
	}

	var body: some View {
		Form {
			if !isAddingEmail {
				modePicker
			}
			fields
			submitSection
		}
		.navigationTitle(isAddingEmail ? "Add Email" : "Email")
		.animation(.smooth, value: mode)
		.animation(.smooth, value: problem)
		.animation(.smooth, value: checked)
		.onChange(of: mode) {
			password = ""
			problem = nil
			checked.remove(.password)
		}
		.onChange(of: focus) { left, _ in
			guard let left, !text(of: left).isEmpty else { return }
			checked.insert(left)
		}
	}

	// MARK: - Sections

	private var modePicker: some View {
		Section {
			Picker("Mode", selection: $mode) {
				Text("Sign In")
					.tag(Mode.signIn)
				Text("Create Account")
					.tag(Mode.createAccount)
			}
			.pickerStyle(.segmented)
			.listRowBackground(Color.clear)
			.listRowInsets(EdgeInsets())
			.accessibilityIdentifier("email.mode")
		}
	}

	private var fields: some View {
		Section {
			TextField("Email", text: $email)
				.keyboardType(.emailAddress)
				.textContentType(.username)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($focus, equals: .email)
				.submitLabel(.next)
				.onSubmit { focus = .password }
				.accessibilityIdentifier("email.address")

			SecureField("Password", text: $password)
				.textContentType(mode == .createAccount ? .newPassword : .password)
				.focused($focus, equals: .password)
				.submitLabel(.go)
				.onSubmit(submit)
				.accessibilityIdentifier("email.password")
				// A new field, so iOS looks at its content type again and offers a strong password
				.id(mode)
		} footer: {
			ShapeIssues(issues: shownIssues)
		}
	}

	private var submitSection: some View {
		Section {
			Button(action: submit) {
				HStack {
					Text(submitTitle)
					if isSending {
						Spacer()
						ProgressView()
					}
				}
			}
			.disabled(email.isEmpty || password.isEmpty || isSending)
			.accessibilityIdentifier("email.submit")
		} footer: {
			submitFooter
		}
	}

	@ViewBuilder
	private var submitFooter: some View {
		if let problem {
			VStack(alignment: .leading, spacing: 6) {
				Text(problem.message)
					.foregroundStyle(.red)

				// Signed in already, signing in to another account would be refused
				if problem.code == .emailInUse, !isAddingEmail {
					Button("Sign In Instead") {
						mode = .signIn
						focus = .password
					}
					.font(.footnote.weight(.semibold))
					.accessibilityIdentifier("email.signInInstead")
				}
			}
		} else {
			Text(explanation)
		}
	}

	// MARK: - Text

	private var submitTitle: String {
		switch mode {
			case .signIn:
				"Sign In"
			case .createAccount:
				isAddingEmail ? "Add Email" : "Create Account"
		}
	}

	private var explanation: String {
		if isAddingEmail {
			return "Sign in on other devices with Apple or with this email. There's no password reset yet, so keep the password in Passwords."
		}
		switch mode {
			case .signIn:
				return "Pages on this iPhone join the account's."
			case .createAccount:
				return "Pages on this iPhone go into the new account. There's no password reset yet, so keep the password in Passwords."
		}
	}

	// MARK: - Checking

	private func text(of field: Field) -> String {
		switch field {
			case .email:
				email
			case .password:
				password
		}
	}

	private var shownIssues: [String] {
		[
			checked.contains(.email) ? Self.emailIssue(email) : nil,
			checked.contains(.password) ? Self.passwordIssue(password) : nil,
		].compactMap(\.self)
	}

	/// The same checks the server makes, worded the same way
	static func emailIssue(_ email: String) -> String? {
		issue { _ = try AccountEmail.normalized(email) }
	}

	static func passwordIssue(_ password: String) -> String? {
		issue { try AccountPassword.check(password) }
	}

	private static func issue(_ check: () throws -> Void) -> String? {
		do {
			try check()
			return nil
		} catch {
			return error.localizedDescription
		}
	}

	// MARK: - Sending

	private func submit() {
		guard !email.isEmpty, !password.isEmpty, !isSending else { return }
		checked = [.email, .password]
		guard Self.emailIssue(email) == nil, Self.passwordIssue(password) == nil else { return }

		let mode = mode
		let password = password
		self.password = ""
		checked.remove(.password)
		isSending = true
		problem = nil

		Task {
			defer { isSending = false }
			do {
				switch mode {
					case .signIn:
						try await sync.logIn(email: email, password: password)
					case .createAccount:
						try await sync.register(email: email, password: password)
				}
				dismiss()
			} catch is CancellationError {
			} catch let error as ServiceError {
				problem = error
			} catch {
				problem = ServiceError(code: .internalError, message: error.localizedDescription)
			}
		}
	}
}

/// What's wrong with the shape of the email or password, before anything is sent
private struct ShapeIssues: View {
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

#Preview("Signed out") {
	NavigationStack {
		EmailSignInView()
	}
	.environment(SyncController.preview(signedIn: false))
}

#Preview("Adding email") {
	NavigationStack {
		EmailSignInView(isAddingEmail: true)
	}
	.environment(SyncController.preview(signedIn: true))
}
