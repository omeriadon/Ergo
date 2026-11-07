//
//  RequestLogMiddleware.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Vapor

/// One line per request with the status it got, so a socket upgrade shows as 101, or as whatever turned it away.
/// Outermost, so it sees the status `ServiceErrorMiddleware` chose. Only the method and path: no query, headers or body,
/// and no token from an ask's tool URL or an invite link.
struct RequestLogMiddleware: AsyncMiddleware {
	func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
		let response = try await next.respond(to: request)
		let upgrade = request.headers.first(name: .upgrade)?.lowercased() == "websocket" ? " (WebSocket upgrade)" : ""
		let path = AskToolController.isToolCall(request) ? "/\(ErgoProtocol.Path.askTools)" : JoinController.loggablePath(of: request)
		request.logger.info("\(request.method) \(path) \(response.status.code)\(upgrade)")
		return response
	}
}
