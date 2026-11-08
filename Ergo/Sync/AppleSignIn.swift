//
//  AppleSignIn.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AuthenticationServices
import CryptoKit
import ErgoProtocol
import Foundation

/// One Sign in with Apple attempt. Apple signs the nonce's hash into the identity token and the server checks the
/// raw nonce against it, so a stolen token can't be replayed.
struct AppleSignIn {
	let nonce: String

	init() {
		var generator = SystemRandomNumberGenerator()
		nonce = (0 ..< 32).map { _ in unsafe String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
	}

	/// Goes in the Apple request
	var hashedNonce: String {
		SHA256.hash(data: Data(nonce.utf8)).map { unsafe String(format: "%02x", $0) }.joined()
	}

	func prepare(_ request: ASAuthorizationAppleIDRequest) {
		// Sync only needs the stable user id, never a name or email
		request.requestedScopes = []
		request.nonce = hashedNonce
	}

	/// The identity token to send the server. Nil when the person cancelled, which isn't an error.
	static func identityToken(from result: Result<ASAuthorization, any Error>) throws -> String? {
		switch result {
			case let .success(authorization):
				guard
					let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
					let data = credential.identityToken,
					let token = String(data: data, encoding: .utf8)
				else {
					throw failed
				}
				return token
			case let .failure(error):
				if let error = error as? ASAuthorizationError, error.code == .canceled {
					return nil
				}
				throw failed
		}
	}

	static let failed = ServiceError(code: .unauthorized, message: "Couldn't sign in with Apple")
}
