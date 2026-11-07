//
//  AskSocket.swift
//  ErgoServer
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoProtocol
import Foundation
import NIOCore
import Vapor

/// `WS v1/ask`: waits for one request, sends the answer as it's written and what its tools do, then `.finished`, and closes.
/// Sending `.cancel` or closing the socket cancels the work, which stops the CLI.
struct AskSocket {
	let request: Request
	let socket: WebSocket

	private enum Incoming: Sendable {
		case text(String)
		case waitedTooLong
	}

	private let incoming: AsyncStream<Incoming>
	private let input: AsyncStream<Incoming>.Continuation

	/// Only on the socket's event loop, straight after the upgrade, so nothing the client sends first is missed
	init(request: Request, socket: WebSocket) {
		self.request = request
		self.socket = socket
		(incoming, input) = AsyncStream.makeStream(of: Incoming.self)

		let input = input
		socket.onText { _, text in
			input.yield(.text(text))
		}
		socket.onBinary { _, buffer in
			input.yield(.text(String(buffer: buffer)))
		}
		socket.onClose.whenComplete { _ in
			input.finish()
		}

		// Proxies drop a quiet connection, and the model can think for a while between tool calls
		socket.pingInterval = TimeAmount(request.ergo.config.pingInterval)
	}

	func run() async {
		let config = request.ergo.config
		guard let account = try? request.accountID else {
			return await finish(.failed(.unknownAccount))
		}

		let timer = Task {
			do {
				try await Task.sleep(for: config.requestWait)
				input.yield(.waitedTooLong)
			} catch {}
		}

		// Only this loop touches `work`, and it lasts until the socket closes
		var work: Task<Void, Never>?
		for await message in incoming {
			switch message {
				case .waitedTooLong:
					if work == nil {
						await finish(.failed(ServiceError(
							code: .timedOut,
							message: "Expected an ask request within \(config.requestWait.spelledOut)"
						)))
					}

				case let .text(text):
					switch try? ErgoProtocol.decoder.decode(AskClientMessage.self, from: Data(text.utf8)) {
						case let .ask(ask)? where work == nil:
							timer.cancel()
							work = Task {
								await answer(ask, account: account)
							}
						case .ask?:
							// The protocol has one request per socket, so a second one changes nothing
							break
						case .cancel?:
							if let work {
								work.cancel()
							} else {
								await close()
							}
						case nil where work == nil:
							await finish(.failed(ServiceError(code: .invalidRequest, message: "Expected an ask request")))
						case nil:
							break
					}
			}
		}

		timer.cancel()
		work?.cancel()
		await work?.value
	}

	private func answer(_ ask: AskRequest, account: UUID) async {
		let port = request.application.http.server.shared.localAddress?.port ?? request.application.http.server.configuration.port
		let reply: AskServerMessage
		do {
			try await request.ergo.ask.ask(ask, port: port, account: account, database: request.db, logger: request.logger) { message in
				await send(message)
			}
			reply = .finished
		} catch {
			// Whoever cancelled has stopped listening
			guard !Task.isCancelled, !(error is CancellationError) else {
				return await close()
			}
			reply = .failed(error as? ServiceError ?? .internalFailure)
		}
		await send(reply)
		await close()
	}

	// MARK: - Sending

	private func send(_ message: AskServerMessage) async {
		guard let data = try? ErgoProtocol.encoder.encode(message) else { return }
		try? await socket.send(String(decoding: data, as: UTF8.self))
	}

	private func finish(_ message: AskServerMessage) async {
		await send(message)
		await close()
	}

	private func close() async {
		try? await socket.close(code: .normalClosure)
	}
}
