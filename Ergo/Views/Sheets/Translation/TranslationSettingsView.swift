//
//  TranslationSettingsView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoClient
import ErgoProtocol
import SwiftUI

struct TranslationSettingsView: View {
	@Environment(TranslationAccount.self)
	private var account

	// Release builds never read these two, but views watch them so a debug build follows a switch
	@Default(.serverEnvironment) var serverEnvironment
	@Default(.translationServer) var translationServer
	@Default(.translationProvider) var translationProvider
	@Default(.agentInstructions) var instructions

	@State private var disconnecting: Provider?

	/// Nil only in a debug build set to This Mac without a usable address
	private var server: URL? {
		ServerEnvironment.effective(serverEnvironment, macAddress: translationServer)
	}

	/// The server's own providers only when it has them, and always the one already chosen
	private var models: [Provider] {
		Provider.allCases.filter { !$0.isServerManaged || account.connections[$0] != nil || $0 == translationProvider }
	}

	var body: some View {
		Form {
			#if DEBUG
				ServerSection()
			#endif

			AIConsentSection()

			Section {
				Picker("Model", selection: $translationProvider) {
					ForEach(models, id: \.self) { provider in
						Text(provider.name)
					}
				}
				.accessibilityIdentifier("translation.provider")
			} footer: {
				Text("Your own Claude or ChatGPT account answers your questions and analyses your boards. Works with Claude Pro or Max, ChatGPT Plus or Pro, or an API key for either.")
			}

			if let usage = account.usage {
				UsageSection(usage: usage)
			}

			Section {
				NavigationLink {
					AgentInstructionsView()
				} label: {
					LabeledContent("Instructions", value: instructions.isEmpty ? "None" : instructions)
						.lineLimit(1)
				}
				.accessibilityIdentifier("translation.instructions")
			}

			Section {
				ForEach(Provider.allCases.filter { !$0.isServerManaged }, id: \.self) { provider in
					NavigationLink {
						switch provider {
							case .claude:
								ConnectClaudeView()
							case .codex:
								ConnectChatGPTView()
							case .openrouter:
								EmptyView()
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
		.toolbarTitleVire("AI", "sparkles")
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
			await account.refreshUsage()
		}
	}
}

#if DEBUG
	/// Debug builds only: pick the hosted server or `ErgoServer` running on the Mac.
	/// Switching signs this device out of the old server's account. Signing in again the same way reaches
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

				ServerTestRows(server: ServerEnvironment.effective(serverEnvironment, macAddress: translationServer))
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
				Text("The address of ErgoServer on your Mac. An iPhone can't reach localhost, so use the Mac's name or IP address. Switching signs you out here, and signing in again reaches the same account.")
			} else {
				Text("Debug builds only. Switching signs you out here, and signing in again reaches the same account.")
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

	/// Debug builds only: tries REST and the translate socket on their own, since one can work while the other doesn't.
	/// Uses this device's token if it has one, and never makes an account.
	private struct ServerTestRows: View {
		let server: URL?

		@State private var attempt = 0
		@State private var testing = false
		@State private var result: (probe: ErgoClient.Probe, hasAccount: Bool)?

		var body: some View {
			Button("Test Server") {
				attempt += 1
			}
			.disabled(server == nil || testing)
			.accessibilityIdentifier("translation.testServer")
			.task(id: attempt) {
				await test()
			}
			.onChange(of: server) {
				result = nil
			}

			if testing {
				ProgressView()
			} else if let result {
				ProbeRow(name: "REST", outcome: result.probe.rest, hasAccount: result.hasAccount)
				ProbeRow(name: "WebSocket", outcome: result.probe.socket, hasAccount: result.hasAccount)
			}
		}

		private func test() async {
			guard attempt > 0, let server else { return }
			testing = true
			defer { testing = false }

			let token = AccountKeychain.token(for: server)
			guard let probe = try? await ErgoClient(server: server, token: token).probe() else { return }
			result = (probe, token != nil)
		}
	}

	private struct ProbeRow: View {
		let name: String
		let outcome: ErgoClient.Probe.Outcome
		let hasAccount: Bool

		var body: some View {
			VStack(alignment: .leading, spacing: 4) {
				Text(name)

				Text(detail)
					.font(.subheadline)
					.foregroundStyle(isFailure ? .red : .secondary)
					.textSelection(.enabled)
			}
		}

		private var detail: String {
			switch outcome {
				case .ok:
					"✓"
				case .noAccount:
					hasAccount ? "✓ Reached, but the server doesn't know this account" : "✓ Reached, no account here yet"
				case let .failed(error):
					error.message
			}
		}

		private var isFailure: Bool {
			if case .failed = outcome {
				return true
			}
			return false
		}
	}
#endif

/// How much of Ergo's model is left. Someone's own Claude or ChatGPT login isn't counted.
private struct UsageSection: View {
	let usage: UsageStatus

	private var percentLeft: Int {
		Int(((1 - min(max(usage.fractionUsed, 0), 1)) * 100).rounded())
	}

	var body: some View {
		Section {
			VStack(alignment: .leading, spacing: 8) {
				LabeledContent("Today", value: "\(percentLeft)% left")
				ProgressView(value: min(max(usage.fractionUsed, 0), 1))
					.tint(usage.fractionUsed >= 0.9 ? .orange : .accent)
				Text("Starts again \(usage.resets, format: .relative(presentation: .named))")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier("translation.usage")

			LabeledContent("Deep Research", value: "\(usage.deepResearchLeft) of \(usage.deepResearchPerWeek) left this week")

			NavigationLink {
				PlusView()
			} label: {
				LabeledContent("Ergo Plus", value: usage.plan == .plus ? "On" : "Off")
			}
			.accessibilityIdentifier("translation.plus")
		} header: {
			Text(Provider.openrouter.name)
		} footer: {
			Text("Only what runs on Ergo's model counts. Your own Claude or ChatGPT account never does.")
		}
	}
}

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

/// Whether what the person writes may go to AI at all. The first run asks; this is where it changes.
private struct AIConsentSection: View {
	@Default(.aiConsent) private var consent

	var body: some View {
		Section {
			Toggle("Send Text to AI", isOn: $consent)
				.accessibilityIdentifier("translation.consent")
		} footer: {
			VStack(alignment: .leading, spacing: 6) {
				Text("Ask, Break Down and Deep Research send what you give them to the company behind the model you choose. Off, everything else still works.")
				LegalLinks()
			}
		}
	}
}

#Preview {
	NavigationStack {
		TranslationSettingsView()
	}
	.environment(TranslationAccount())
}
