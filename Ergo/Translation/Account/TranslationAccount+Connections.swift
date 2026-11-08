//
//  TranslationAccount+Connections.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

extension TranslationAccount {
	// MARK: - connect

	func connect(_ provider: Provider, _ upload: ConnectionUpload) async throws -> ConnectionStatus {
		let server = server
		let status = try await withClient { try await $0.connect(provider, upload) }
		if self.server == server {
			await recordConnection(status)
		}
		return status
	}

	/// Settings won't ask again on its own, so connections that weren't known are asked for now
	func recordConnection(_ status: ConnectionStatus) async {
		if knownConnections != nil {
			knownConnections?[status.provider] = status
		} else {
			await refresh()
		}
	}

	func disconnect(_ provider: Provider) async {
		guard let server else {
			knownConnections?[provider] = nil
			return
		}
		switch AccountKeychain.lookup(for: server) {
			case .missing:
				knownConnections?[provider] = nil
				return
			case .unavailable:
				problem = Self.keychainUnavailable.message
				return
			case .found:
				break
		}

		do {
			try await withClient { try await $0.disconnect(provider) }
			guard self.server == server else { return }
			knownConnections?[provider] = nil
			problem = nil
		} catch is CancellationError {
		} catch {
			guard self.server == server else { return }
			problem = error.localizedDescription
		}
	}

	/// Runs ChatGPT's device login on the server. `code` is called once with what to enter where.
	func codexDeviceLogin(code: (URL, String) -> Void) async throws -> ConnectionStatus {
		let server = server
		let status = try await withClient { client in
			for try await message in client.codexDeviceLogin() {
				switch message {
					case let .code(url, value):
						code(url, value)
					case let .connected(status):
						return status
					case let .failed(error):
						throw error
				}
			}
			try Task.checkCancellation()
			throw Self.disconnected
		}
		if self.server == server {
			await recordConnection(status)
		}
		return status
	}
}
