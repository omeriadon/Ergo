//
//  Report.swift
//  Evals
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoProtocol
import Foundation

/// One scored run, with the totals worked out so the JSON can be read without ErgoKit
struct EvalResult: Codable, Sendable {
	let evalCase: EvalCase
	let run: EvalRun
	let score: Score
	let formalizeAttempts: Int
	let verifyRan: Bool
	let hasVerifyWarnings: Bool

	init(evalCase: EvalCase, run: EvalRun) {
		self.evalCase = evalCase
		self.run = run
		score = Scoring.score(run, for: evalCase)
		formalizeAttempts = run.formalizeAttempts
		verifyRan = run.verifyRan
		hasVerifyWarnings = run.hasVerifyWarnings
	}
}

struct EvalReport: Codable, Sendable {
	let date: Date
	let server: URL
	let provider: Provider
	let results: [EvalResult]

	/// `Results/<ISO date>-<provider>.md` and `.json`
	func write(to directory: URL = Corpus.results) throws -> [URL] {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

		let formatter = ISO8601DateFormatter()
		// No colons, they're awkward in file names
		formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
		let stem = formatter.string(from: date) + "-" + provider.rawValue

		let encoder = ErgoProtocol.encoder
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

		let markdown = directory.appending(path: stem + ".md")
		let json = directory.appending(path: stem + ".json")
		try Data(self.markdown().utf8).write(to: markdown)
		try encoder.encode(self).write(to: json)
		return [markdown, json]
	}

	// MARK: - Markdown

	func markdown() -> String {
		let summary = Summary(results)
		let cases = Set(results.map(\.evalCase.id)).count
		var lines = [
			"# Ergo eval: \(provider.rawValue), \(date.formatted(date: .abbreviated, time: .shortened))",
			"",
			"\(server.absoluteString), \(summary.runs) runs of \(cases) cases.",
			"",
			"## Overall",
			"",
			"| Runs | Pass | Mean | p90 | Formalize attempts | Retried | Verify warnings |",
			"|---:|---:|---:|---:|---:|---:|---:|",
			"| \(summary.runs) | \(summary.passText) | \(seconds(summary.meanSeconds)) | \(seconds(summary.p90Seconds)) "
				+ "| \(String(format: "%.2f", summary.meanAttempts)) | \(summary.retried) | \(summary.warned) |",
			"",
			"| Outcome | Runs |",
			"|---|---:|",
		]
		lines += Outcome.allCases.map { "| \($0.rawValue) | \(summary.outcomes[$0, default: 0]) |" }

		lines += [
			"",
			"## By tag",
			"",
			"| Tag | Runs | Pass | Mean | Attempts |",
			"|---|---:|---:|---:|---:|",
		]
		let tags = Set(results.flatMap(\.evalCase.tags)).sorted()
		for tag in tags {
			let tagged = Summary(results.filter { $0.evalCase.tags.contains(tag) })
			lines.append("| \(tag) | \(tagged.runs) | \(tagged.passText) | \(seconds(tagged.meanSeconds)) | \(String(format: "%.2f", tagged.meanAttempts)) |")
		}

		let failures = results.filter { $0.score.outcome != .pass }
		lines += ["", "## Failures", ""]
		guard !failures.isEmpty else {
			return (lines + ["None.", ""]).joined(separator: "\n")
		}

		lines += [
			"| Case | Outcome | Expected | Got | Problem |",
			"|---|---|---|---|---|",
		]
		lines += failures.map { result in
			let score = result.score
			return "| \(cell(label(result))) | \(score.outcome.rawValue) | \(cell(score.expected)) | \(cell(score.got)) | \(cell(score.problem)) |"
		}

		// Long and multi-line, so they go under the table rather than in it
		let readable = failures.filter { $0.score.gotReading != nil }
		if !readable.isEmpty {
			lines += ["", "## Readings"]
		}
		for result in readable {
			lines += [
				"",
				"### \(label(result)), \(result.score.outcome.rawValue)",
				"",
				quoted(result.evalCase.english),
				"",
				"Expected `\(result.score.expected ?? "")`",
				"",
				quoted(result.score.expectedReading ?? ""),
				"",
				"Got `\(result.score.got ?? "")`",
				"",
				quoted(result.score.gotReading ?? ""),
			]
		}

		return (lines + [""]).joined(separator: "\n")
	}

	private func label(_ result: EvalResult) -> String {
		let repeated = results.contains { $0.evalCase.id == result.evalCase.id && $0.run.repetition > 1 }
		return repeated ? "\(result.evalCase.id) #\(result.run.repetition)" : result.evalCase.id
	}

	private func cell(_ text: String?) -> String {
		(text ?? "").replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
	}

	private func quoted(_ text: String) -> String {
		text.split(separator: "\n", omittingEmptySubsequences: false).map { "> " + $0 }.joined(separator: "\n")
	}

	private func seconds(_ value: Double) -> String {
		String(format: "%.1f s", value)
	}
}

// MARK: - Summary

struct Summary {
	let runs: Int
	let passes: Int
	let outcomes: [Outcome: Int]
	let meanSeconds: Double

	/// Nearest rank, so it's always a time some run actually took
	let p90Seconds: Double

	/// Only over runs that got as far as formalize
	let meanAttempts: Double

	/// Needed more than one formalize attempt
	let retried: Int

	let warned: Int

	init(_ results: [EvalResult]) {
		runs = results.count
		outcomes = results.reduce(into: [:]) { $0[$1.score.outcome, default: 0] += 1 }
		passes = outcomes[.pass, default: 0]

		let times = results.map(\.run.seconds).sorted()
		meanSeconds = times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
		p90Seconds = times.isEmpty ? 0 : times[Int((Double(times.count) * 0.9).rounded(.up)) - 1]

		let attempts = results.map(\.formalizeAttempts).filter { $0 > 0 }
		meanAttempts = attempts.isEmpty ? 0 : Double(attempts.reduce(0, +)) / Double(attempts.count)
		retried = attempts.count { $0 > 1 }
		warned = results.count(where: \.hasVerifyWarnings)
	}

	var passText: String {
		runs == 0 ? "0" : "\(passes) (\(Int((Double(passes) / Double(runs) * 100).rounded()))%)"
	}
}
