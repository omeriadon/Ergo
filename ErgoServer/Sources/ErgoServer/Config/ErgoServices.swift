//
//  ErgoServices.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoAsk
import ErgoCatalog
import Foundation
import Vapor

/// What every route shares, made once in `configure`
struct ErgoServices: Sendable {
	let config: ServerConfig
	let vault: CredentialVault
	let runner: ProcessRunner
	let accountLimiter: CreateAccountLimiter
	let registerLimiter: CreateAccountLimiter
	let loginLimiter: LoginLimiter
	let appleNotificationLimiter: CreateAccountLimiter
	let appleNotifications: SeenNotifications

	/// What an unknown email's password is checked against, so it takes as long as a known one's
	let dummyPasswordHash: String
	let translations: TranslationService
	let ask: AskService
	let askTools: AskToolServer
	let verifier: ConnectionVerifier
	let apple: AppleTokenVerifier
	let syncLimits: SyncLimits
	let live: SyncLive
	let sync: SyncService

	init(config: ServerConfig, verifier: ConnectionVerifier? = nil, apple: AppleTokenVerifier? = nil) throws {
		let runner = ProcessRunner(
			prefix: config.runnerPrefix,
			owner: config.runnerUser.flatMap(ProcessRunner.Owner.init(named:)),
			maxProcesses: config.maxProcesses,
			timeout: config.stageTimeout
		)

		self.config = config
		self.runner = runner
		let vault = CredentialVault(key: config.vaultKey)
		self.vault = vault
		accountLimiter = CreateAccountLimiter(limit: config.accountsPerHour)
		registerLimiter = CreateAccountLimiter(limit: config.registrationsPerHour)
		loginLimiter = LoginLimiter(limit: config.failedLoginsPerWindow, window: config.loginWindow)
		appleNotificationLimiter = CreateAccountLimiter(limit: config.appleNotificationsPerMinute, window: 60)
		appleNotifications = SeenNotifications()
		dummyPasswordHash = try Bcrypt.hash(UUID().uuidString, cost: config.passwordCost)
		let translations = TranslationService(vault: vault, config: config, runner: runner)
		self.translations = translations
		ask = AskService(translations: translations)
		askTools = try AskToolServer(tools: AskTools(catalog: LibraryCatalog.load()))
		self.verifier = verifier ?? .live(config: config, runner: runner)
		self.apple = apple ?? .live(applicationIdentifier: config.appleApplicationID)
		syncLimits = SyncLimits(requestsPerMinute: config.syncsPerMinute)
		let live = SyncLive()
		self.live = live
		sync = SyncService(vault: vault, live: live, recordsPerAccount: config.recordsPerAccount)
	}
}

extension Application {
	private struct ServicesKey: StorageKey {
		typealias Value = ErgoServices
	}

	/// Set by `configure`, before any route can run
	var ergo: ErgoServices {
		get {
			guard let services = storage[ServicesKey.self] else {
				fatalError("Expected configure(_:) to set up ErgoServices before the first request")
			}
			return services
		}
		set {
			storage[ServicesKey.self] = newValue
		}
	}
}

extension Request {
	var ergo: ErgoServices {
		application.ergo
	}
}
