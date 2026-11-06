//
//  ErgoEvaluation.swift
//  ErgoSiriEvaluations
//
//  Created by Adon Omeri on 6/11/2026.
//

import SiriEvaluations
import Testing

/// Declared once per test target: a name, a dataset, the Siri run, the expectation evaluator and the
/// standard report.
struct ErgoEvaluation: Evaluation {
	let name: String
	let dataset: SiriScenarioLoader

	func subject(from sample: SiriScenario) async throws -> SiriScenarioSubject {
		try await SiriService.run(scenario: sample)
	}

	var evaluators: Evaluators {
		SiriExpectationEvaluator()
	}

	func aggregateMetrics(using aggregator: inout MetricsAggregator) {
		Self.computeSiriMetrics(into: &aggregator)
	}
}
