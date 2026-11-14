//
//  AIConsentTests.swift
//  ErgoTests
//
//  Created by Adon Omeri on 14/11/2026.
//

import Defaults
@testable import Ergo
import ErgoProtocol
import Foundation
import Testing

/// Nothing goes to a model until the person allows it. Each of these throws before looking for a server, so none of them
/// reaches one.
@Suite(.cleanDefaults)
struct AIConsentTests {
	@Test func aNewInstallHasNotAllowedAI() {
		#expect(!Defaults[.aiConsent])
	}

	@Test func askingWithoutPermissionThrowsBeforeSendingAnything() async {
		let account = TranslationAccount(signedIn: nil)

		let error = await #expect(throws: ServiceError.self) {
			try await account.ask(id: UUID(), messages: []) { _ in }
		}

		#expect(error?.message == TranslationAccount.noAIConsent.message)
		#expect(error?.code == .notConnected)
	}

	@Test func breakingDownWithoutPermissionThrows() async {
		let account = TranslationAccount(signedIn: nil)
		let request = account.breakDownRequest(english: "It rained, so the ground is wet.", descriptors: [])

		let error = await #expect(throws: ServiceError.self) {
			_ = try await account.breakDown(request) { _ in }
		}

		#expect(error?.message == TranslationAccount.noAIConsent.message)
	}

	@Test func deepResearchWithoutPermissionThrows() async {
		let account = TranslationAccount(signedIn: nil)
		let request = BoardAnalysisRequest(run: UUID(), provider: .claude, statements: [], links: [], sources: [])

		let error = await #expect(throws: ServiceError.self) {
			try await account.startAnalysis(board: "board", request)
		}

		#expect(error?.message == TranslationAccount.noAIConsent.message)
	}

	@Test func allowingItLetsTheCheckThrough() throws {
		let account = TranslationAccount(signedIn: nil)
		Defaults[.aiConsent] = true

		try account.requireAIConsent()
	}
}
