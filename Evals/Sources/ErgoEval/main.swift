//
//  main.swift
//  Evals
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoClient
import ErgoProtocol
import Foundation

// MARK: - Options

/// Few enough flags that a hand-rolled loop is clearer than a dependency
struct Options {
	static let usage = """
	Usage: swift run ErgoEval --server <url> --provider <claude|codex> [--token <account token>]
	                          [--tag <tag>]... [--case <id>]... [--repeat <n>] [--concurrency <n>]

	The token can also come from ERGO_EVAL_TOKEN. The account must already have the provider connected.
	--tag and --case can be repeated, and a case runs when it matches any of them.
	--concurrency above 1 needs one account per translation, the server runs one at a time per account.
	"""

	var server: URL?
	var token = ProcessInfo.processInfo.environment["ERGO_EVAL_TOKEN"]
	var provider: Provider?
	var tags: [String] = []
	var cases: [String] = []
	var repetitions = 1
	var concurrency = 1

	init(_ arguments: [String]) throws {
		var remaining = arguments[...]

		func value(for flag: String) throws -> String {
			guard let value = remaining.popFirst(), !value.hasPrefix("--") else {
				throw EvalError("Expected a value after '\(flag)'")
			}
			return value
		}

		func count(for flag: String) throws -> Int {
			let text = try value(for: flag)
			guard let count = Int(text), count > 0 else {
				throw EvalError("Expected a positive number after '\(flag)', found '\(text)'")
			}
			return count
		}

		while let flag = remaining.popFirst() {
			switch flag {
				case "--server":
					let text = try value(for: flag)
					guard let url = URL(string: text), url.scheme == "http" || url.scheme == "https" else {
						throw EvalError("Expected an http or https URL, found '\(text)'")
					}
					server = url
				case "--token":
					token = try value(for: flag)
				case "--provider":
					let text = try value(for: flag)
					guard let named = Provider(rawValue: text) else {
						throw EvalError("Expected 'claude' or 'codex', found '\(text)'")
					}
					provider = named
				case "--tag":
					try tags.append(value(for: flag))
				case "--case":
					try cases.append(value(for: flag))
				case "--repeat":
					repetitions = try count(for: flag)
				case "--concurrency":
					concurrency = try count(for: flag)
				default:
					throw EvalError("Unknown option '\(flag)'")
			}
		}

		if server == nil {
			throw EvalError("Expected '--server'")
		}
		if provider == nil {
			throw EvalError("Expected '--provider'")
		}
		if token?.isEmpty ?? true {
			throw EvalError("Expected '--token' or ERGO_EVAL_TOKEN")
		}
	}

	/// Everything when nothing is picked
	func selected(from all: [EvalCase]) throws -> [EvalCase] {
		let ids = Set(all.map(\.id))
		if let unknown = cases.first(where: { !ids.contains($0) }) {
			throw EvalError("Unknown case '\(unknown)'")
		}
		if let unknown = tags.first(where: { tag in !all.contains { $0.tags.contains(tag) } }) {
			throw EvalError("No cases tagged '\(unknown)'")
		}

		guard !tags.isEmpty || !cases.isEmpty else { return all }
		return all.filter { evalCase in
			cases.contains(evalCase.id) || evalCase.tags.contains { tags.contains($0) }
		}
	}
}

// MARK: - Run

func fail(_ message: String, status: Int32) -> Never {
	FileHandle.standardError.write(Data((message + "\n").utf8))
	exit(status)
}

if CommandLine.arguments.contains("--help") {
	print(Options.usage)
	exit(0)
}

let options: Options
do {
	options = try Options(Array(CommandLine.arguments.dropFirst()))
} catch {
	fail("error: \(error)\n\n\(Options.usage)", status: 64)
}

let corpus: [EvalCase]
do {
	corpus = try Corpus.load().flatMap(\.cases)
} catch {
	fail("error: \(error)", status: 65)
}

/// The same checks as the offline tests, so a broken answer key never gets scored against
let broken = corpus.filter { !$0.problems.isEmpty }
if !broken.isEmpty {
	fail(broken.map { "error: \($0.id): \($0.problems.joined(separator: "; "))" }.joined(separator: "\n"), status: 65)
}

let selected: [EvalCase]
do {
	selected = try options.selected(from: corpus)
} catch {
	fail("error: \(error)", status: 64)
}

guard let server = options.server, let provider = options.provider else {
	fail(Options.usage, status: 64)
}

let runner = Runner(client: ErgoClient(server: server, token: options.token), provider: provider, concurrency: options.concurrency)
let started = Date.now

let runs = await runner.run(selected, repetitions: options.repetitions) { evalCase, run in
	let outcome = Scoring.score(run, for: evalCase).outcome
	let line = outcome.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0) + evalCase.id + String(format: "  %.1f s", run.seconds)
	FileHandle.standardError.write(Data((line + "\n").utf8))
}

let byID = Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) })
let report = EvalReport(
	date: started,
	server: server,
	provider: provider,
	results: runs.compactMap { run in byID[run.caseID].map { EvalResult(evalCase: $0, run: run) } }
)

print(report.markdown())

do {
	let files = try report.write()
	FileHandle.standardError.write(Data(("Wrote " + files.map(\.path).joined(separator: " and ") + "\n").utf8))
} catch {
	fail("error: Couldn't write the results: \(error)", status: 73)
}
