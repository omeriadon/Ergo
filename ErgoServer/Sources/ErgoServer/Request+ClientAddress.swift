//
//  Request+ClientAddress.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import NIOCore
import Vapor

extension Request {
	/// Who is really asking, for the per-address limits. Behind a proxy every request comes from the proxy's
	/// own address, so with `ERGO_TRUST_PROXY` the address the proxy appended to `X-Forwarded-For` is used instead.
	var clientAddress: String {
		ClientAddress.resolve(
			peer: remoteAddress?.ipAddress,
			forwardedFor: headers[.xForwardedFor],
			trustProxy: application.ergo.config.trustProxy
		)
	}
}

enum ClientAddress {
	static let unknown = "unknown"

	/// The socket's own address, unless `trustProxy` and the socket is a local proxy (nginx on the same machine).
	/// Then it's the right-most `X-Forwarded-For` entry that isn't local itself: what the proxy appended is the
	/// only part of the header the client can't write, and everything left of it is the client's to make up.
	/// A request that reached the server directly is never trusted, whatever header it carries.
	static func resolve(peer: String?, forwardedFor: [String], trustProxy: Bool) -> String {
		guard let peer else { return unknown }
		guard trustProxy, isLoopback(peer) else { return peer }

		let hops = forwardedFor.flatMap { $0.split(separator: ",") }.map { $0.trimmingCharacters(in: .whitespaces) }
		for hop in hops.reversed() {
			// Something that isn't an address means the proxy isn't what we think it is
			guard isAddress(hop) else { return peer }
			if !isLoopback(hop) {
				return hop
			}
		}
		return peer
	}

	private static func isLoopback(_ address: String) -> Bool {
		address.hasPrefix("127.") || address == "::1" || address.lowercased().hasPrefix("::ffff:127.")
	}

	private static func isAddress(_ text: String) -> Bool {
		(try? SocketAddress(ipAddress: text, port: 0)) != nil
	}
}
