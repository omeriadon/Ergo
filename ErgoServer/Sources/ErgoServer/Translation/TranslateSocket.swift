//
//  TranslateSocket.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Foundation
import NIOCore
import Vapor

/// `WS v1/translate`: waits for one request, sends each pipeline event as it happens, then the translation, and closes.
/// Sending `.cancel` or closing the socket cancels the work, which stops the CLI.
struct TranslateSocket {
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

		// Proxies drop a quiet connection, and a translation can take a minute
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
							message: "Expected a translate request within \(config.requestWait.spelledOut)"
						)))
					}

				case let .text(text):
					switch try? ErgoProtocol.decoder.decode(TranslateClientMessage.self, from: Data(text.utf8)) {
						case let .translate(translate)? where work == nil:
							timer.cancel()
							work = Task {
								await self.translate(translate, account: account)
							}
						case .translate?:
							// The protocol has one request per socket, so a second one changes nothing
							break
						case .cancel?:
							if let work {
								work.cancel()
							} else {
								await close()
							}
						case nil where work == nil:
							await finish(.failed(ServiceError(code: .invalidRequest, message: "Expected a translate request")))
						case nil:
							break
					}
			}
		}

		timer.cancel()
		work?.cancel()
		await work?.value
	}

	private func translate(_ translate: TranslateRequest, account: UUID) async {
		let reply: TranslateServerMessage
		do {
			let translation = try await request.ergo.translations.translate(
				translate,
				account: account,
				database: request.db,
				logger: request.logger
			) { event in
				await send(.event(event))
			}
			reply = .finished(translation)
		} catch {
			// Whoever cancelled has stopped listening
			guard !Task.isCancelled, !(error is CancellationError) else {
				return await close()
			}
			reply = .failed(error as? ServiceError ?? .internalFailure)
		}
		await finish(reply)
	}

	// MARK: - Sending

	private func send(_ message: TranslateServerMessage) async {
		guard let data = try? ErgoProtocol.encoder.encode(message) else { return }
		try? await socket.send(String(decoding: data, as: UTF8.self))
	}

	private func finish(_ message: TranslateServerMessage) async {
		await send(message)
		await close()
	}

	private func close() async {
		try? await socket.close(code: .normalClosure)
	}
}
