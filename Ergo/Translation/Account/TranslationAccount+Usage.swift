//
//  TranslationAccount+Usage.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import DeviceCheck
import ErgoClient
import ErgoProtocol
import Foundation

extension TranslationAccount {
	/// Nothing is held back until the server says it should be, and the server still has the last word
	var hasPlusFeatures: Bool {
		usage?.hasPlusFeatures ?? true
	}

	/// Asks the server what's left, and claims this phone's free allowance if the account hasn't got one. An account that
	/// hasn't signed in can use Ergo's model too. This never makes one. What was known stays if the server can't be reached.
	func refreshUsage() async {
		guard let existing = try? credentials() else {
			usage = nil
			return
		}
		let client = ErgoClient(server: existing.server, token: existing.token)
		guard let status = try? await client.usage() else { return }
		usage = status
		if status.needsDeviceClaim, let token = await Self.deviceToken(), let claimed = try? await client.claimDevice(token: token) {
			usage = claimed
		}
	}

	/// `transaction` is an App Store transaction as Apple signed it
	func uploadPlan(transaction: String) async throws {
		guard let client = syncClient else {
			throw Self.notSignedIn
		}
		usage = try await client.uploadPlan(transaction: transaction)
	}

	/// Nil where DeviceCheck can't run, like the simulator
	private static func deviceToken() async -> String? {
		guard DCDevice.current.isSupported else { return nil }
		return try? await DCDevice.current.generateToken().base64EncodedString()
	}
}
