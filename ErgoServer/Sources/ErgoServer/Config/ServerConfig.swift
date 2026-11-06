//
//  ServerConfig.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import Crypto
import ErgoProtocol
import FluentPostgresDriver
import Foundation
import Logging

/// Everything the environment can change, read once at launch
struct ServerConfig: Sendable {
	var databasePath = "./ergo.sqlite"

	/// The Postgres database to use. Nil uses the SQLite file at `databasePath`.
	var postgres: SQLPostgresConfiguration?

	/// Seals credentials at rest
	var vaultKey: SymmetricKey

	/// Where each CLI call gets its own scratch directory
	var runsDirectory = FileManager.default.temporaryDirectory.appending(path: "ergo-runs", directoryHint: .isDirectory)

	var claudePath: String?
	var codexPath: String?

	struct CLIInstall: Sendable {
		var directory: URL
		var npmPath: String
		var claudeCodeVersion: String
		var codexVersion: String
	}

	/// Where a CLI that doesn't run gets installed at launch, and at which version. Nil never installs.
	var cliInstall: CLIInstall?

	/// Put before every CLI, so the CLIs can run as a user that can't read the database or the key
	var runnerPrefix: [String] = []

	/// Who owns a run directory while a CLI runs in it, when the prefix switches to another user
	var runnerUser: String?

	var maxProcesses = 8
	var stageTimeout: Duration = .seconds(120)
	var models = StageModels.defaults

	/// The audience Sign in with Apple tokens must have: the app's bundle id
	var appleApplicationID = "com.adonis.Ergo"

	/// Whether `X-Forwarded-For` says who is asking, for the per-address limits. Only for a server behind a proxy
	/// on the same machine or private network, since otherwise anyone could write it.
	var trustProxy = false

	// MARK: - Fixed, but shortened by tests

	var requestWait: Duration = .seconds(10)
	var pingInterval: Duration = .seconds(20)
	var deviceLoginTimeout: Duration = .seconds(15 * 60)
	var accountsPerHour = 5
	var registrationsPerHour = 10

	/// Generous, since every user's notifications come from Apple's few addresses
	var appleNotificationsPerMinute = 120

	/// Failed logins per address, and per email, within `loginWindow`
	var failedLoginsPerWindow = 10
	var loginWindow: TimeInterval = 15 * 60

	/// bcrypt's cost, 2^cost rounds. Tests lower it to the minimum, which still checks passwords.
	var passwordCost = 12
	var syncsPerMinute = SyncLimit.requestsPerMinute
	var recordsPerAccount = SyncLimit.recordsPerAccount

	/// How often tombstones are pruned, first at launch. Nil never prunes, so tests prune by hand.
	var pruneInterval: Duration? = .seconds(24 * 60 * 60)

	init(vaultKey: SymmetricKey) {
		self.vaultKey = vaultKey
	}

	// MARK: - Environment

	struct Problem: Error, CustomStringConvertible {
		let description: String
	}

	/// Production refuses to start without a vault key. Development makes one up, so its credentials only last until a restart.
	static func load(from environment: [String: String], production: Bool, logger: Logger) throws -> ServerConfig {
		var config = try ServerConfig(vaultKey: vaultKey(from: environment, production: production, logger: logger))

		if let path = environment["ERGO_DATABASE_PATH"] {
			config.databasePath = path
		}
		if let url = environment["ERGO_DATABASE_URL"], !url.isEmpty {
			// The driver's own error quotes the URL, which holds the password, and this one gets logged
			guard let postgres = try? SQLPostgresConfiguration(url: url) else {
				throw Problem(description: "ERGO_DATABASE_URL: Expected postgres://user:password@host:port/database")
			}
			config.postgres = postgres
		}
		if let path = environment["ERGO_RUNS_DIRECTORY"] {
			config.runsDirectory = URL(filePath: path, directoryHint: .isDirectory)
		}

		let searchPath = environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
		config.claudePath = environment["ERGO_CLAUDE_PATH"] ?? executable(named: "claude", in: searchPath)
		config.codexPath = environment["ERGO_CODEX_PATH"] ?? executable(named: "codex", in: searchPath)

		if let directory = environment["ERGO_CLI_DIRECTORY"], !directory.isEmpty {
			guard let npm = executable(named: "npm", in: searchPath) else {
				throw Problem(description: "ERGO_CLI_DIRECTORY: Expected npm on PATH to install the CLIs, found none")
			}
			guard let claudeCode = environment["ERGO_CLAUDE_CODE_VERSION"], let codex = environment["ERGO_CODEX_VERSION"] else {
				throw Problem(description: "ERGO_CLI_DIRECTORY: Expected ERGO_CLAUDE_CODE_VERSION and ERGO_CODEX_VERSION to go with it")
			}
			config.cliInstall = CLIInstall(
				directory: URL(filePath: directory, directoryHint: .isDirectory),
				npmPath: npm,
				claudeCodeVersion: claudeCode,
				codexVersion: codex
			)
		}

		if let prefix = environment["ERGO_RUNNER_PREFIX"] {
			config.runnerPrefix = prefix.split(whereSeparator: \.isWhitespace).map(String.init)
		}
		config.runnerUser = environment["ERGO_RUNNER_USER"].flatMap { $0.isEmpty ? nil : $0 }

		if let value = environment["ERGO_MAX_PROCESSES"] {
			guard let count = Int(value), count > 0 else {
				throw Problem(description: "ERGO_MAX_PROCESSES: Expected a positive whole number, found '\(value)'")
			}
			config.maxProcesses = count
		}
		if let value = environment["ERGO_STAGE_TIMEOUT"] {
			guard let seconds = Int(value), seconds > 0 else {
				throw Problem(description: "ERGO_STAGE_TIMEOUT: Expected a positive number of seconds, found '\(value)'")
			}
			config.stageTimeout = .seconds(seconds)
		}
		if let path = environment["ERGO_MODELS_FILE"] {
			config.models = try StageModels.load(from: URL(filePath: path))
		}
		if let id = environment["ERGO_APPLE_APP_ID"] {
			guard !id.trimmingCharacters(in: .whitespaces).isEmpty else {
				throw Problem(description: "ERGO_APPLE_APP_ID: Expected the app's bundle id, found nothing")
			}
			config.appleApplicationID = id
		}

		if let value = environment["ERGO_TRUST_PROXY"] {
			switch value.lowercased() {
				case "1", "true":
					config.trustProxy = true
				case "0", "false", "":
					config.trustProxy = false
				default:
					throw Problem(description: "ERGO_TRUST_PROXY: Expected 1, true, 0 or false, found '\(value)'")
			}
		}

		if config.claudePath == nil {
			logger.warning("Couldn't find 'claude' on PATH, Claude connections will fail until ERGO_CLAUDE_PATH is set")
		}
		if config.codexPath == nil {
			logger.warning("Couldn't find 'codex' on PATH, ChatGPT connections will fail until ERGO_CODEX_PATH is set")
		}

		return config
	}

	private static func vaultKey(from environment: [String: String], production: Bool, logger: Logger) throws -> SymmetricKey {
		var encoded = environment["ERGO_VAULT_KEY"]
		if encoded == nil, let file = environment["ERGO_VAULT_KEY_FILE"] {
			do {
				encoded = try String(contentsOf: URL(filePath: file), encoding: .utf8)
			} catch {
				throw Problem(description: "ERGO_VAULT_KEY_FILE: Couldn't read '\(file)'")
			}
		}

		guard let encoded else {
			guard !production else {
				throw Problem(description: "Expected ERGO_VAULT_KEY or ERGO_VAULT_KEY_FILE, 32 bytes of base64")
			}
			logger.warning("No ERGO_VAULT_KEY, using a random one, so stored credentials won't survive a restart")
			return SymmetricKey(size: .bits256)
		}

		guard let data = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)), data.count == 32 else {
			throw Problem(description: "ERGO_VAULT_KEY: Expected 32 bytes of base64")
		}
		return SymmetricKey(data: data)
	}

	private static func executable(named name: String, in searchPath: String) -> String? {
		searchPath
			.split(separator: ":")
			.map { "\($0)/\(name)" }
			.first { FileManager.default.isExecutableFile(atPath: $0) }
	}
}
