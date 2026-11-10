//
//  TranslationAccount+Requests.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import ErgoTranslation
import Foundation

extension TranslationAccount {
	// MARK: - translate

	/// The request that splits pasted English into premises, a conclusion and claims, without writing any logic. Its `id`
	/// names the run on the server, which carries on if this app is closed: `breakDown` with the same request again
	/// picks that run up. `descriptors` are whatever the caller already names; the board ignores the ones that come back.
	/// `letters` default to the ones the app shows.
	func breakDownRequest(english: String, descriptors: [String], letters: [String]? = nil) -> TranslateRequest {
		translateRequest(
			english: english,
			letters: letters ?? LogicLetters.resolved(Defaults[.logicLetters]),
			descriptors: descriptors
		)
	}

	/// Runs the server's argument scope on `request` and hears it. `events` hears each step as the server runs it. The
	/// server's failures are thrown as `ServiceError`s.
	///
	/// The server doesn't stop when this connection does, so a dropped one is `ConnectionLost`, not a failure: call again
	/// with the same request to hear it from the start.
	func breakDown(_ request: TranslateRequest, events: (TranslationEvent) -> Void) async throws -> ArgumentBreakdown {
		let (server, token) = try credentials()

		return try await signedOutOnUnauthorized(of: server) {
			var failure: ServiceError?
			do {
				for try await message in ErgoClient(server: server, token: token).breakDown(request) {
					switch message {
						case let .event(event):
							events(event)
						case let .finished(breakdown):
							return breakdown
						case let .failed(error):
							failure = error
					}
					if failure != nil {
						break
					}
				}
			} catch {
				throw Self.connectionLost(error)
			}
			if let failure {
				throw failure
			}
			try Task.checkCancellation()
			throw ConnectionLost(underlying: Self.disconnected)
		}
	}

	/// Answers the last of `messages`. `events` hears the answer as it's written, what its tools do and the buttons it
	/// adds. The server's failures are thrown as `ServiceError`s.
	///
	/// `id` names the run on the server, which carries on if this app is closed. Calling again with the same `id` hears it
	/// from the start, and starts it again if the server no longer has it. A dropped connection is `ConnectionLost`.
	///
	/// `board` is the board the chat is about, as it is now, which gives the model tools to change it.
	func ask(id: UUID, messages: [AskRequestMessage], mode: AskMode = .normal, board: AskBoard? = nil, events: (AskServerMessage) -> Void) async throws {
		let (server, token) = try credentials()
		let request = AskRequest(id: id, provider: Defaults[.translationProvider], messages: messages, instructions: Defaults[.agentInstructions], mode: mode, board: board)

		try await signedOutOnUnauthorized(of: server) {
			var failure: ServiceError?
			do {
				for try await message in ErgoClient(server: server, token: token).ask(request) {
					switch message {
						case .finished:
							return
						case let .failed(error):
							failure = error
						default:
							events(message)
					}
					if failure != nil {
						break
					}
				}
			} catch {
				throw Self.connectionLost(error)
			}
			if let failure {
				throw failure
			}
			try Task.checkCancellation()
			throw ConnectionLost(underlying: Self.disconnected)
		}
	}

	/// The connection to a run dropped, which says nothing about the run: the server carries on without it
	struct ConnectionLost: Error {
		let underlying: ServiceError
	}

	/// Only the client's own "couldn't reach" and "lost connection" errors count. A 401 or 403 on the upgrade is a different
	/// problem, and a cancellation is neither.
	static func connectionLost(_ error: any Error) -> any Error {
		guard let error = error as? ServiceError, error.code == .providerUnavailable else { return error }
		return ConnectionLost(underlying: error)
	}

	/// Hands a board to the server, which carries on without this request. Its results come back through sync.
	func startAnalysis(board: String, _ request: BoardAnalysisRequest) async throws {
		try await withSyncClient { try await $0.startBoardAnalysis(board: board, request) }
	}

	/// Stops the board's run, keeping what it has written
	func stopAnalysis(board: String) async throws {
		try await withSyncClient { try await $0.stopBoardAnalysis(board: board) }
	}

	/// Like sync, it needs an account that's signed in. The server forgetting the token ends the sign-in.
	func withSyncClient(_ work: (ErgoClient) async throws -> Void) async throws {
		guard let signedIn, let client = syncClient else {
			throw Self.notSignedIn
		}
		do {
			try await work(client)
		} catch let error as ServiceError where error.code == .unauthorized {
			forgetToken(for: signedIn.server)
			throw error
		}
	}

	func credentials() throws -> (server: URL, token: String) {
		let provider = Defaults[.translationProvider]
		guard let server else {
			throw Self.notSetUp
		}
		switch AccountKeychain.lookup(for: server) {
			case let .found(token):
				return (server, token)
			case .missing:
				throw Self.notConnected(provider)
			case .unavailable:
				throw Self.keychainUnavailable
		}
	}

	/// `scope` is set by the client method that sends it
	func translateRequest(english: String, letters: [String], descriptors: [String]) -> TranslateRequest {
		TranslateRequest(
			id: UUID(),
			english: english,
			provider: Defaults[.translationProvider],
			letters: letters,
			grammarVersion: LogicGrammar.version,
			// Nothing named yet is the same as not saying
			descriptors: descriptors.allSatisfy(\.isEmpty) ? nil : descriptors
		)
	}

	func signedOutOnUnauthorized<Result>(of server: URL, _ work: () async throws -> Result) async throws -> Result {
		do {
			return try await work()
		} catch let error as ServiceError where error.code == .unauthorized {
			// The server forgot this account, and a new one has nothing connected
			forgetToken(for: server)
			throw Self.notConnected(Defaults[.translationProvider])
		}
	}
}
