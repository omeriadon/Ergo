//
//  ConnectChatGPTView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import SwiftUI

struct ConnectChatGPTView: View {
	/// What the server's `codex login` asks the user to enter, and where
	private struct DeviceCode: Hashable {
		let url: URL
		let code: String
	}

	@Environment(TranslationAccount.self)
	private var account

	@Environment(\.dismiss)
	private var dismiss

	// MARK: - Sign in

	@State private var signingIn: Task<Void, Never>?
	@State private var deviceCode: DeviceCode?
	@State private var signInProblem: String?

	// MARK: - Paste

	@State private var kind = CredentialKind.subscription

	/// Only held until it's uploaded
	@State private var secret = ""

	@State private var isConnecting = false
	@State private var pasteProblem: String?

	var body: some View {
		Form {
			Section {
				if let deviceCode {
					VStack(spacing: 12) {
						Text(deviceCode.code)
							.font(.largeTitle.weight(.semibold))
							.monospaced()
							.textSelection(.enabled)
							.frame(maxWidth: .infinity)

						CopyButton(text: deviceCode.code)
							.labelStyle(.titleAndIcon)
					}
					.padding(.vertical, 8)

					SwiftUI.Link(destination: deviceCode.url) {
						Label("Open ChatGPT", systemImage: "safari")
					}

					LabeledContent("Waiting for ChatGPT") {
						ProgressView()
					}
					.foregroundStyle(.secondary)
				} else if signingIn != nil {
					LabeledContent("Getting a code") {
						ProgressView()
					}
					.foregroundStyle(.secondary)
				} else {
					Button("Sign in with ChatGPT", action: signIn)
						.disabled(isConnecting)
				}
			} footer: {
				if let signInProblem {
					Text(signInProblem)
						.foregroundStyle(.red)
				} else {
					Text("Device code sign-in has to be turned on in ChatGPT's security settings. Works with ChatGPT Plus or Pro.")
				}
			}

			Section {
				Picker("Kind", selection: $kind) {
					Text("auth.json")
						.tag(CredentialKind.subscription)
					Text("API key")
						.tag(CredentialKind.apiKey)
				}
				.pickerStyle(.segmented)

				switch kind {
					case .subscription:
						TextField("Contents of auth.json", text: $secret, axis: .vertical)
							.lineLimit(4 ... 8)
							.monospaced()
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
					case .apiKey:
						SecureField("API key", text: $secret)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
				}

				Button(action: connect) {
					HStack {
						Text("Connect")
						if isConnecting {
							Spacer()
							ProgressView()
						}
					}
				}
				.disabled(secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting || signingIn != nil)
			} header: {
				Text("Or Paste")
			} footer: {
				if let pasteProblem {
					Text(pasteProblem)
						.foregroundStyle(.red)
				} else {
					switch kind {
						case .subscription:
							Text("It's in `~/.codex/auth.json` after `codex login` on a computer.")
						case .apiKey:
							Text("An OpenAI API key. Usage is billed to its account.")
					}
				}
			}
		}
		.navigationTitle("ChatGPT")
		// Signing in inside the app keeps it in the foreground, so the login socket isn't dropped
		.environment(\.openURL, OpenURLAction { url in
			.systemAction(url, prefersInApp: true)
		})
		.animation(.smooth, value: deviceCode)
		.animation(.smooth, value: signInProblem)
		.animation(.smooth, value: pasteProblem)
		.onChange(of: kind) {
			secret = ""
			pasteProblem = nil
		}
		.onDisappear {
			// Closing the socket cancels the login on the server
			signingIn?.cancel()
			signingIn = nil
		}
	}

	private func signIn() {
		signInProblem = nil

		signingIn = Task {
			do {
				_ = try await account.codexDeviceLogin { url, code in
					deviceCode = DeviceCode(url: url, code: code)
				}
				guard !Task.isCancelled else { return }
				dismiss()
			} catch {
				guard !Task.isCancelled, !(error is CancellationError) else { return }
				signInProblem = error.localizedDescription
			}
			deviceCode = nil
			signingIn = nil
		}
	}

	private func connect() {
		let upload = ConnectionUpload(kind: kind, secret: secret.trimmingCharacters(in: .whitespacesAndNewlines))
		guard !upload.secret.isEmpty, !isConnecting else { return }

		isConnecting = true
		pasteProblem = nil

		Task {
			defer { isConnecting = false }
			do {
				_ = try await account.connect(.codex, upload)
				secret = ""
				dismiss()
			} catch is CancellationError {
			} catch {
				pasteProblem = error.localizedDescription
			}
		}
	}
}

#Preview {
	NavigationStack {
		ConnectChatGPTView()
	}
	.environment(TranslationAccount())
}
