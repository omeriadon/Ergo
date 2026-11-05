//
//  TranslationSettingsView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoProtocol
import SwiftUI

struct TranslationSettingsView: View {
	@Environment(TranslationAccount.self)
	private var account

	// Release builds never read these two, but views watch them so a debug build follows a switch
	@Default(.serverEnvironment) var serverEnvironment
	@Default(.translationServer) var translationServer
	@Default(.translationProvider) var translationProvider

	@State private var disconnecting: Provider?

	/// Nil only in a debug build set to This Mac without a usable address
	private var server: URL? {
		ServerEnvironment.effective(serverEnvironment, macAddress: translationServer)
	}

	var body: some View {
		Form {
			#if DEBUG
				ServerSection()
			#endif

			Section {
				Picker("Model", selection: $translationProvider) {
					ForEach(Provider.allCases, id: \.self) { provider in
						Text(provider.name)
					}
				}
				.accessibilityIdentifier("translation.provider")
			} footer: {
				Text("Your own Claude or ChatGPT account does the translating. Works with Claude Pro or Max, ChatGPT Plus or Pro, or an API key for either.")
			}

			Section {
				ForEach(Provider.allCases, id: \.self) { provider in
					NavigationLink {
						switch provider {
							case .claude:
								ConnectClaudeView()
							case .codex:
								ConnectChatGPTView()
						}
					} label: {
						ConnectionRow(provider: provider, status: account.connections[provider])
					}
					.swipeActions {
						if account.connections[provider] != nil {
							Button("Disconnect", systemImage: "minus.circle", role: .destructive) {
								disconnecting = provider
							}
						}
					}
					.accessibilityIdentifier("translation.connect.\(provider.rawValue)")
				}
			} header: {
				Text("Connections")
			} footer: {
				if let problem = account.problem {
					Text(problem)
						.foregroundStyle(.red)
				}
			}
			.disabled(server == nil)
		}
		.toolbarTitleVire("Logic Translation", "translate")
		.confirmationDialog(
			disconnecting.map { "Disconnect \($0.name)?" } ?? "",
			isPresented: Binding(
				get: {
					disconnecting != nil
				},
				set: { presented in
					if !presented {
						disconnecting = nil
					}
				}
			),
			titleVisibility: .visible,
			presenting: disconnecting
		) { provider in
			Button("Disconnect", role: .destructive) {
				Task {
					await account.disconnect(provider)
				}
			}
		} message: { provider in
			Text("The server forgets your \(provider.name) credential. Translating with \(provider.name) needs it connected again.")
		}
		.task(id: server) {
			await account.refresh()
		}
	}
}

#if DEBUG
	/// Debug builds only: pick the hosted server or `ErgoServer` running on the Mac.
	/// Switching signs this device out of the old server's account. Signing in again with the same Apple ID reaches
	/// the same account there, and each server keeps its own token, so nothing is lost by switching back.
	private struct ServerSection: View {
		@Default(.serverEnvironment) var serverEnvironment
		@Default(.translationServer) var translationServer

		@State private var macDraft = ""
		@State private var macProblem: String?

		var body: some View {
			Section {
				Picker("Server", selection: $serverEnvironment) {
					ForEach(ServerEnvironment.allCases, id: \.self) { environment in
						Text(environment.name)
					}
				}
				.accessibilityIdentifier("translation.environment")

				if serverEnvironment == .thisMac {
					TextField("http://Adons-Mac.local:8080", text: $macDraft)
						.keyboardType(.URL)
						.textContentType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.onSubmit(commitMac)
						.accessibilityIdentifier("translation.server")
				}
			} header: {
				Text("Server")
			} footer: {
				footer
			}
			.onAppear {
				macDraft = translationServer
			}
		}

		@ViewBuilder
		private var footer: some View {
			if let macProblem {
				Text(macProblem)
					.foregroundStyle(.red)
			} else if serverEnvironment == .thisMac {
				Text("The address of ErgoServer on your Mac. An iPhone can't reach localhost, so use the Mac's name or IP address. Switching signs you out here, and signing in again with the same Apple ID reaches the same account.")
			} else {
				Text("Debug builds only. Switching signs you out here, and signing in again with the same Apple ID reaches the same account.")
			}
		}

		private func commitMac() {
			if macDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				macProblem = nil
				translationServer = ""
				return
			}

			guard let url = ServerEnvironment.macURL(from: macDraft) else {
				macProblem = "Expected a server address, like 'http://Adons-Mac.local:8080'"
				return
			}

			macProblem = nil
			macDraft = url.absoluteString
			translationServer = url.absoluteString
		}
	}
#endif

private struct ConnectionRow: View {
	let provider: Provider
	let status: ConnectionStatus?

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(provider.name)

			Group {
				if let status {
					if let problem = status.problem {
						Text(problem)
							.foregroundStyle(.red)
					} else if let verified = status.verified {
						Text("Connected · verified \(verified, format: .relative(presentation: .named))")
					} else {
						Text("Connected")
					}
				} else {
					Text("Not connected")
				}
			}
			.font(.subheadline)
			.foregroundStyle(.secondary)
		}
	}
}

#Preview {
	NavigationStack {
		TranslationSettingsView()
	}
	.environment(TranslationAccount())
}
