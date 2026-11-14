//
//  ConnectClaudeView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import SwiftUI

struct ConnectClaudeView: View {
	@Environment(TranslationAccount.self)
	private var account

	@Environment(\.dismiss)
	private var dismiss

	@State private var kind = CredentialKind.subscription

	/// Only held until it's uploaded
	@State private var secret = ""

	@State private var isConnecting = false
	@State private var problem: String?

	var body: some View {
		Form {
			Section {
				Picker("Kind", selection: $kind) {
					Text("Subscription")
						.tag(CredentialKind.subscription)
					Text("API key")
						.tag(CredentialKind.apiKey)
				}
				.pickerStyle(.segmented)
				.listRowBackground(Color.clear)
				.listRowInsets(EdgeInsets())
			}

			Section {
				if kind == .subscription {
					CommandRow(command: "claude setup-token")
				}

				SecureField(kind == .subscription ? "Token" : "API key", text: $secret)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.onSubmit(connect)
			} footer: {
				switch kind {
					case .subscription:
						Text("On a computer with Claude Code, run `claude setup-token`, then paste the token here. Works with Claude Pro or Max.")
					case .apiKey:
						Text("An Anthropic API key. Usage is billed to its account.")
				}
			}

			Section {
				Button(action: connect) {
					HStack {
						Text("Connect")
						if isConnecting {
							Spacer()
							ProgressView()
						}
					}
				}
				.disabled(secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
			} footer: {
				if let problem {
					Text(problem)
						.foregroundStyle(.red)
				}
			}
		}
		.navigationTitle("Claude")
		.animation(.smooth, value: kind)
		.animation(.smooth, value: problem)
		.onChange(of: kind) {
			secret = ""
			problem = nil
		}
	}

	private func connect() {
		let upload = ConnectionUpload(kind: kind, secret: secret.trimmingCharacters(in: .whitespacesAndNewlines))
		guard !upload.secret.isEmpty, !isConnecting else { return }

		isConnecting = true
		problem = nil

		Task {
			defer { isConnecting = false }
			do {
				_ = try await account.connect(.claude, upload)
				secret = ""
				dismiss()
			} catch is CancellationError {
			} catch {
				problem = error.localizedDescription
			}
		}
	}
}

/// A command to run on a computer, with a button to copy it
struct CommandRow: View {
	let command: String

	var body: some View {
		HStack {
			Text(command)
				.monospaced()
				.textSelection(.enabled)

			Spacer(minLength: 0)

			CopyButton(text: command)
		}
	}
}

struct CopyButton: View {
	let text: String

	var body: some View {
		Button("Copy", systemImage: "doc.on.doc") {
			#if os(iOS)
				UIPasteboard.general.string = text
			#else
				NSPasteboard.general.clearContents()
				NSPasteboard.general.setString(text, forType: .string)
			#endif
		}
		.labelStyle(.iconOnly)
		.buttonStyle(.borderless)
	}
}

#Preview {
	NavigationStack {
		ConnectClaudeView()
	}
	.environment(TranslationAccount())
}
