//
//  AccountKeychain.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation
import Security

/// The Ergo account token, one per server.
/// Everything else lives in Defaults, but this is a secret, so it's the one thing kept in the Keychain.
enum AccountKeychain {
	private static let service = "com.omeriadon.Ergo.translation"

	enum Lookup {
		case found(String)
		/// Nothing stored, as opposed to the Keychain not answering
		case missing
		/// The Keychain couldn't be read, so this says nothing about whether there's a token
		case unavailable
	}

	static func lookup(for server: URL) -> Lookup {
		var query = query(for: server)
		query[kSecReturnData as String] = true
		query[kSecMatchLimit as String] = kSecMatchLimitOne

		var result: AnyObject?
		switch SecItemCopyMatching(query as CFDictionary, &result) {
			case errSecSuccess:
				guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
					return .unavailable
				}
				return .found(token)
			case errSecItemNotFound:
				return .missing
			default:
				return .unavailable
		}
	}

	/// Nil for missing and unavailable alike, for callers that don't care which
	static func token(for server: URL) -> String? {
		if case let .found(token) = lookup(for: server) {
			return token
		}
		return nil
	}

	/// Nil deletes it
	static func setToken(_ token: String?, for server: URL) {
		let query = query(for: server)
		SecItemDelete(query as CFDictionary)

		guard let token else { return }
		var item = query
		item[kSecValueData as String] = Data(token.utf8)
		item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
		SecItemAdd(item as CFDictionary, nil)
	}

	private static func query(for server: URL) -> [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account(for: server),
		]
	}

	/// Host and port, so `https://host` and `https://host:443` share an account
	private static func account(for server: URL) -> String {
		let port = server.port ?? (server.scheme == "http" ? 80 : 443)
		return "\(server.host() ?? ""):\(port)"
	}
}
