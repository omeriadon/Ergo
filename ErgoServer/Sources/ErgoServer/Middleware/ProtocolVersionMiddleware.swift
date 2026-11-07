//
//  ProtocolVersionMiddleware.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Vapor

/// Turns away any app built against another protocol, before it can misread a reply. Apple's notifications, the
/// CLIs' tool calls and the two public pages for invite links are the exceptions, since none comes from the app and none
/// has heard of the header.
struct ProtocolVersionMiddleware: AsyncMiddleware {
	func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
		guard AppleNotificationController.isNotification(request)
			|| AskToolController.isToolCall(request)
			|| JoinController.isPublic(request)
			|| request.headers.first(name: ErgoProtocol.versionHeader) == String(ErgoProtocol.version)
		else {
			throw ServiceError(code: .outdatedApp, message: "Expected Ergo with protocol \(ErgoProtocol.version), update the app")
		}
		return try await next.respond(to: request)
	}
}
