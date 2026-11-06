//
//  RunDirectory.swift
//  ErgoServer
//
//  Created by Adon Omeri on 5/11/2026.
//

import Foundation

/// A fresh, private directory for one CLI call: `home/` stands in for the user's home, `work/` is where it runs.
/// Nothing in it outlives the call.
struct RunDirectory: Sendable {
	let root: URL

	var home: URL {
		root.appending(path: "home", directoryHint: .isDirectory)
	}

	var work: URL {
		root.appending(path: "work", directoryHint: .isDirectory)
	}

	var temporary: URL {
		home.appending(path: "tmp", directoryHint: .isDirectory)
	}

	/// Makes one, hands it to `body`, and removes it afterwards however `body` ends
	static func with<T>(in parent: URL, _ body: (RunDirectory) async throws -> T) async throws -> T {
		let run = try make(in: parent)
		defer { run.remove() }
		return try await body(run)
	}

	/// The parent can be passed through but not listed, so the runner user can reach the run it's handed without seeing the others
	static func make(in parent: URL) throws -> RunDirectory {
		let files = FileManager.default
		try files.createDirectory(at: parent, withIntermediateDirectories: true)
		try files.setAttributes([.posixPermissions: 0o711], ofItemAtPath: parent.path)

		let run = RunDirectory(root: parent.appending(path: UUID().uuidString, directoryHint: .isDirectory))
		// The server enters `work` for a CLI before the prefix switches users, after the run was handed over, so the
		// way there can be passed through. What's secret is in `home`.
		for (directory, permissions) in [(run.root, 0o711), (run.home, 0o700), (run.temporary, 0o700), (run.work, 0o711)] {
			try files.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: permissions])
		}
		return run
	}

	/// Written `0600`, since some of these are secrets
	func write(_ text: String, to file: URL) throws {
		try FileManager.default.createDirectory(
			at: file.deletingLastPathComponent(),
			withIntermediateDirectories: true,
			attributes: [.posixPermissions: 0o700]
		)
		guard FileManager.default.createFile(atPath: file.path, contents: Data(text.utf8), attributes: [.posixPermissions: 0o600]) else {
			throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: file.path])
		}
	}

	func read(_ file: URL) -> String? {
		(try? Data(contentsOf: file)).map { String(decoding: $0, as: UTF8.self) }
	}

	func remove() {
		try? FileManager.default.removeItem(at: root)
	}

	// MARK: - Handing over

	/// Gives everything inside to the runner user, so a CLI running as that user can use it
	func handOver(to owner: ProcessRunner.Owner) throws {
		try chown(owner)
	}

	/// Takes it back afterwards, so the server can read what the CLI left and delete it
	func takeBack() {
		try? chown(ProcessRunner.Owner(user: getuid(), group: getgid()))
	}

	private func chown(_ owner: ProcessRunner.Owner) throws {
		let attributes: [FileAttributeKey: Any] = [.ownerAccountID: owner.user, .groupOwnerAccountID: owner.group]
		let files = FileManager.default
		try files.setAttributes(attributes, ofItemAtPath: root.path)
		guard let contents = files.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
		for case let file as URL in contents {
			try files.setAttributes(attributes, ofItemAtPath: file.path)
		}
	}
}
