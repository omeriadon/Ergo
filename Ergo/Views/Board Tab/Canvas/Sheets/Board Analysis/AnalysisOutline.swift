//
//  AnalysisOutline.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoProtocol
import ErgoSync
import SwiftUI

// MARK: - What's listed

/// The board's things that have something to say, in the order the sheet lists them
struct AnalysisOutline {
	struct Thing: Identifiable {
		let id: String
		let heading: String

		/// The annotations about it
		let annotations: [BoardAnnotation]

		/// An arrow or a conclusion the run didn't get to
		let isUnassessed: Bool

		/// A text source's text, to highlight the quotes in
		let text: String?
	}

	struct Group: Identifiable {
		let title: String
		let things: [Thing]

		var id: String {
			title
		}
	}

	let groups: [Group]

	var isEmpty: Bool {
		groups.allSatisfy { $0.things.allSatisfy { $0.annotations.isEmpty && !$0.isUnassessed } }
	}

	init(board: Board, current: [BoardAnnotation], focus: BoardAnalysisTarget?) {
		let builder = Builder(board: board, current: current)
		if let focus {
			groups = builder.focused(on: focus)
		} else {
			groups = builder.all()
		}
	}

	private struct Builder {
		let board: Board
		let current: [BoardAnnotation]

		private var conclusions: Set<Statement.ID> {
			Set(board.links.map(\.conclusion))
		}

		private func annotations(of target: BoardAnalysisTarget, assessed: Bool? = nil) -> [BoardAnnotation] {
			current.filter { annotation in
				annotation.target == target && (assessed.map { $0 == (annotation.assessment != nil) } ?? true)
			}
		}

		private func card(_ statement: Statement, assessed: Bool?) -> Thing {
			let found = annotations(of: .statement(statement.id), assessed: assessed)
			return Thing(
				id: statement.id.uuidString,
				heading: StatementBoxView.title(of: statement),
				annotations: found,
				isUnassessed: assessed == true && found.isEmpty,
				text: nil
			)
		}

		@MainActor
		private func arrow(_ link: Link) -> Thing {
			let found = annotations(of: .link(link.id))
			let premise = board.statement(link.premise).map(StatementBoxView.title(of:)) ?? "Missing statement"
			let conclusion = board.statement(link.conclusion).map(StatementBoxView.title(of:)) ?? "Missing statement"
			return Thing(
				id: link.id.uuidString,
				heading: "\(premise) → \(conclusion)",
				annotations: found,
				isUnassessed: !found.contains { $0.assessment != nil },
				text: nil
			)
		}

		private func source(_ source: BoardSource) -> Thing {
			var text: String?
			if case let .text(body) = source.content {
				text = body
			}
			return Thing(
				id: source.id.uuidString,
				heading: source.title,
				annotations: annotations(of: .source(source.id)),
				isUnassessed: false,
				text: text
			)
		}

		func all() -> [Group] {
			let conclusions = conclusions
			return [
				Group(title: "Conclusions", things: board.statements.filter { conclusions.contains($0.id) }.map { card($0, assessed: true) }),
				Group(title: "Arrows", things: board.links.map { arrow($0) }),
				Group(title: "Cards", things: board.statements.map { card($0, assessed: false) }.filter { !$0.annotations.isEmpty }),
				Group(title: "Sources", things: board.sources.map(source).filter { !$0.annotations.isEmpty }),
			].filter { !$0.things.isEmpty }
		}

		func focused(on target: BoardAnalysisTarget) -> [Group] {
			switch target {
				case let .statement(id):
					guard let statement = board.statement(id) else { return [] }
					var thing = card(statement, assessed: nil)
					let isUnassessed = conclusions.contains(id) && !thing.annotations.contains { $0.assessment != nil }
					thing = Thing(id: thing.id, heading: thing.heading, annotations: thing.annotations, isUnassessed: isUnassessed, text: nil)
					return [Group(title: "Card", things: [thing])]
				case let .link(id):
					guard let link = board.links.first(where: { $0.id == id }) else { return [] }
					return [Group(title: "Arrow", things: [arrow(link)])]
				case let .source(id):
					guard let found = board.source(id) else { return [] }
					return [Group(title: "Source", things: [source(found)])]
			}
		}
	}
}
