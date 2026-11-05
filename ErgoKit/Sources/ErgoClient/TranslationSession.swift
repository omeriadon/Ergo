//
//  TranslationSession.swift
//  ErgoKit
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

public extension ErgoClient {
	/// Events as they happen, finishing with the translation. Cancelling the consuming task cancels the work on the server.
	///
	/// The server's own failures arrive as `.failed`, the last message. Thrown errors mean the server couldn't be reached
	/// or dropped the connection.
	func translate(_ request: TranslateRequest) -> AsyncThrowingStream<TranslateServerMessage, Error> {
		messages(
			at: ErgoProtocol.Path.translate,
			opening: Self.text(TranslateClientMessage.translate(request)),
			closing: Self.text(TranslateClientMessage.cancel)
		) { message in
			switch message {
				case .event:
					false
				case .finished, .failed:
					true
			}
		}
	}
}
