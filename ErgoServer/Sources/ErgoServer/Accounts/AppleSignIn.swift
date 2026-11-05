//
//  AppleSignIn.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import Crypto
import ErgoProtocol
import Foundation
import JWT
import Vapor

/// What a verified Sign in with Apple token says
struct AppleIdentity: Sendable, Hashable {
	/// The same on every device with the same Apple ID
	let subject: String

	/// `SHA256(nonce)` as lowercase hex, as the app put it in the Apple request
	let nonce: String?
}

/// Checks an identity token's signature against Apple's published keys, its issuer, expiry and audience.
/// A closure, so tests can stand in for Apple without the network.
struct AppleTokenVerifier: Sendable {
	/// Throws a `ServiceError`
	let verify: @Sendable (String, Request) async throws -> AppleIdentity

	func callAsFunction(_ identityToken: String, on request: Request) async throws -> AppleIdentity {
		try await verify(identityToken, request)
	}

	/// Apple's keys are fetched once and cached as long as Apple says
	static func live(applicationIdentifier: String) -> AppleTokenVerifier {
		AppleTokenVerifier { identityToken, request in
			do {
				let token = try await request.jwt.apple.verify(identityToken, applicationIdentifier: applicationIdentifier)
				return AppleIdentity(subject: token.subject.value, nonce: token.nonce)
			} catch let error as JWTError {
				request.logger.info("Apple sign-in refused", metadata: ["reason": "\(error.errorType)"])
				throw ServiceError(code: .invalidRequest, message: "Couldn't verify the Sign in with Apple token")
			} catch {
				request.logger.warning("Couldn't fetch Apple's keys", metadata: ["error": "\(String(reflecting: error))"])
				throw ServiceError(code: .providerUnavailable, message: "Couldn't reach Apple to check the sign-in")
			}
		}
	}

	// MARK: - Nonce

	/// What the app puts in the Apple request for `nonce`, and so what the token's `nonce` claim must be
	static func hash(nonce: String) -> String {
		SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
	}

	/// The token's nonce must be this sign-in's, so a token caught on its way to another server can't be replayed here
	static func check(_ identity: AppleIdentity, nonce: String) throws {
		guard !nonce.isEmpty, let claim = identity.nonce else {
			throw ServiceError(code: .invalidRequest, message: "Expected a nonce in the Sign in with Apple token")
		}
		guard claim == hash(nonce: nonce) else {
			throw ServiceError(code: .invalidRequest, message: "Expected the Sign in with Apple token for this sign-in, found another one")
		}
	}
}
