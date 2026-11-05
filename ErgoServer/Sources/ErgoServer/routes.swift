//
//  routes.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Vapor

/// Every path comes from `ErgoProtocol.Path`, so the app and the server can't disagree
func routes(_ app: Application) throws {
	app.post(ErgoProtocol.Path.accounts.pathComponents, use: AccountController.create)

	let signedIn = app.grouped(AccountAuthenticator())
	let connection = ErgoProtocol.Path.connections.pathComponents + [":provider"]

	signedIn.delete(ErgoProtocol.Path.account.pathComponents, use: AccountController.delete)
	signedIn.delete(ErgoProtocol.Path.accountToken.pathComponents, use: AccountController.signOut)
	signedIn.post(ErgoProtocol.Path.appleSignIn.pathComponents, use: AccountController.signInWithApple)
	signedIn.post(ErgoProtocol.Path.register.pathComponents, use: EmailController.register)
	signedIn.post(ErgoProtocol.Path.logIn.pathComponents, use: EmailController.logIn)
	signedIn.post(ErgoProtocol.Path.password.pathComponents, use: EmailController.changePassword)

	signedIn.get(ErgoProtocol.Path.connections.pathComponents, use: ConnectionController.list)
	// An auth.json is a few kilobytes, more than Vapor's default
	signedIn.on(.PUT, connection, body: .collect(maxSize: "64kb"), use: ConnectionController.connect)
	signedIn.delete(connection, use: ConnectionController.disconnect)

	signedIn.webSocket(ErgoProtocol.Path.deviceLogin.pathComponents) { request, socket in
		await CodexDeviceLogin(request: request, socket: socket).run()
	}
	// Not the async upgrade, which starts on another thread and could miss the request
	signedIn.webSocket(ErgoProtocol.Path.translate.pathComponents, maxFrameSize: .init(integerLiteral: 1 << 16)) { request, socket in
		let translate = TranslateSocket(request: request, socket: socket)
		Task {
			await translate.run()
		}
	}

	let synced = signedIn.grouped(RequireSignedIn())
	synced.on(.POST, ErgoProtocol.Path.sync.pathComponents, body: .collect(maxSize: ByteCount(value: SyncLimit.requestBytes)), use: SyncController.sync)
	// Registers straight away on the socket's event loop, so a push just after the upgrade can't be missed
	synced.webSocket(ErgoProtocol.Path.syncLive.pathComponents, maxFrameSize: .init(integerLiteral: 1 << 12)) { request, socket in
		guard let account = try? request.accountID, let token = try? request.tokenID else {
			return socket.close(code: .policyViolation, promise: nil)
		}
		request.ergo.live.listen(socket, account: account, token: token, pingInterval: request.ergo.config.pingInterval)
	}
}
