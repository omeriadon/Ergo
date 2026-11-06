//
//  RunDirectoryTests.swift
//  ErgoServer
//
//  Created by Adon Omeri on 6/11/2026.
//

@testable import ErgoServer
import Foundation
import Testing

struct RunDirectoryTests {
	private func permissions(of directory: URL) throws -> Int {
		try #require(FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int)
	}

	/// In Docker the server enters `work` as itself, after the run belongs to the runner user
	@Test func theServerCanEnterWorkButNotHome() throws {
		let scratch = try Scratch()
		defer { scratch.remove() }

		let run = try RunDirectory.make(in: URL(filePath: scratch.path("runs"), directoryHint: .isDirectory))
		#expect(try permissions(of: run.root) == 0o711)
		#expect(try permissions(of: run.work) == 0o711)
		#expect(try permissions(of: run.home) == 0o700)
		#expect(try permissions(of: run.temporary) == 0o700)
	}
}
