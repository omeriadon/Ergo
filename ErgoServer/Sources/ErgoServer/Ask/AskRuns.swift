//
//  AskRuns.swift
//  ErgoServer
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoProtocol
import Foundation
import Synchronization

/// The asks running right now, each under a random token. A CLI reaches its run's tools with that token in the URL,
/// so what its tools do ends up on the right socket. A token only reads the library and adds buttons to its own answer,
/// and it's gone when the answer is.
final class AskRuns: Sendable {
	typealias Listener = @Sendable (AskServerMessage) async -> Void

	private let runs = Mutex<[String: Listener]>([:])

	func register(_ listener: @escaping Listener) -> String {
		let token = (0 ..< 32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
		runs.withLock { $0[token] = listener }
		return token
	}

	func remove(_ token: String) {
		runs.withLock { _ = $0.removeValue(forKey: token) }
	}

	func listener(for token: String) -> Listener? {
		runs.withLock { $0[token] }
	}
}
