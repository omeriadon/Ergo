//
//  CanvasOutlineView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

/// The canvas as a list, for VoiceOver and for anyone who finds it easier to read: every statement in reading
/// order with the premises it rests on. Everything the canvas does to a statement can be done from here.
struct CanvasOutlineView: View {
	/// Something the outline needs a second answer for
	private enum Question: Hashable, Identifiable {
		case premiseOf(Statement.ID)
		case removeLinkOf(Statement.ID)

		var id: Self {
			self
		}
	}

	let page: LogicPage
	let verdicts: [Statement.ID: BoxVerdict]
	let edit: (Statement.ID) -> Void
	let delete: (Statement.ID) -> Void
	let showCheck: (Statement.ID) -> Void
	let link: (_ premise: Statement.ID, _ conclusion: Statement.ID) -> Void
	let unlink: (Link.ID) -> Void

	@Environment(CatalogStore.self)
	private var catalog

	@Default(.logicLetters) private var logicLetters

	@State private var question: Question?

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	private var map: ArgumentMap<Statement, Link> {
		page.map
	}

	private var ordered: [Statement] {
		map.topologicalOrder().compactMap { page.statement($0) }
	}

	var body: some View {
		List {
			ForEach(ordered) { statement in
				row(for: statement)
			}
		}
		.scrollContentBackground(.hidden)
		.contentMargins(.bottom, 150, for: .scrollContent)
		.confirmationDialog(
			heading(for: question),
			isPresented: Binding(get: { question != nil }, set: {
				if !$0 {
					question = nil
				}
			}),
			titleVisibility: .visible,
			presenting: question
		) { question in
			choices(for: question)
		}
		.accessibilityIdentifier("check.outline")
	}

	// MARK: - Rows

	private func row(for statement: Statement) -> some View {
		Button {
			edit(statement.id)
		} label: {
			rowLabel(for: statement)
		}
		.buttonStyle(.plain)
		.listRowBackground(Rectangle().fill(.regularMaterial))
		.swipeActions {
			Button("Delete", systemImage: "trash", role: .destructive) {
				delete(statement.id)
			}
		}
		.contextMenu {
			actions(for: statement)
		}
		.modifier(OutlineRowSpeech(
			id: statement.id,
			edit: { edit(statement.id) },
			delete: { delete(statement.id) },
			makePremise: { question = .premiseOf(statement.id) },
			removeLink: { question = .removeLinkOf(statement.id) }
		))
	}

	private func rowLabel(for statement: Statement) -> some View {
		let premises: [String] = map.premises(of: statement.id).compactMap { page.statement($0) }.map { title($0) }
		let conclusions: [String] = map.conclusions(of: statement.id).compactMap { page.statement($0) }.map { title($0) }

		return VStack(alignment: .leading, spacing: 4) {
			Text(statement.englishLine ?? title(statement))
				.font(.body)

			if !premises.isEmpty {
				Text(sentence("Rests on", premises))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			if !conclusions.isEmpty {
				Text(sentence("Premise of", conclusions))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			if let verdict = verdicts[statement.id] {
				Text("Check: \(verdict.title(in: catalog))")
					.font(.subheadline.weight(.medium))
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.contentShape(Rectangle())
	}

	private func sentence(_ lead: String, _ names: [String]) -> String {
		"\(lead) \(names.formatted(.list(type: .and)))"
	}

	@ViewBuilder
	private func actions(for statement: Statement) -> some View {
		Button("Edit", systemImage: "square.and.pencil") { edit(statement.id) }
		Button("Make Premise of…", systemImage: "arrow.turn.down.right") { question = .premiseOf(statement.id) }
		if map.premises(of: statement.id).isEmpty == false || map.conclusions(of: statement.id).isEmpty == false {
			Button("Remove Link…", systemImage: "link.badge.minus") { question = .removeLinkOf(statement.id) }
		}
		if verdicts[statement.id] != nil {
			Button("Show Check", systemImage: "checkmark.seal") { showCheck(statement.id) }
		}
		Button("Delete", systemImage: "trash", role: .destructive) { delete(statement.id) }
	}

	// MARK: - Questions

	private func heading(for question: Question?) -> String {
		switch question {
			case .premiseOf: "Make a premise of"
			case .removeLinkOf: "Remove the link to"
			case nil: ""
		}
	}

	@ViewBuilder
	private func choices(for question: Question) -> some View {
		switch question {
			case let .premiseOf(id):
				// Only the statements an arrow could go to, so a choice never gets refused
				ForEach(page.statements.filter { canLink(id, to: $0.id) }) { target in
					Button(title(target)) { link(id, target.id) }
				}

			case let .removeLinkOf(id):
				ForEach(page.links.filter { $0.premise == id || $0.conclusion == id }) { link in
					Button(describe(link, from: id)) { unlink(link.id) }
				}
		}
	}

	private func canLink(_ premise: Statement.ID, to conclusion: Statement.ID) -> Bool {
		ArgumentMapValidator.problem(adding: Link(premise: premise, conclusion: conclusion), to: map) == nil
	}

	private func describe(_ link: Link, from id: Statement.ID) -> String {
		let other = link.premise == id ? link.conclusion : link.premise
		let name: String = page.statement(other).map { title($0) } ?? "Unknown"
		return link.premise == id ? "Premise of \(name)" : "Rests on \(name)"
	}

	private func title(_ statement: Statement) -> String {
		StatementBoxView.title(of: statement, letters: letters)
	}
}

/// What VoiceOver can do to a row without a swipe or a long press
private struct OutlineRowSpeech: ViewModifier {
	let id: Statement.ID
	let edit: () -> Void
	let delete: () -> Void
	let makePremise: () -> Void
	let removeLink: () -> Void

	func body(content: Content) -> some View {
		content
			.accessibilityElement(children: .combine)
			.accessibilityAction(named: Text("Edit"), edit)
			.accessibilityAction(named: Text("Delete"), delete)
			.accessibilityAction(named: Text("Make premise of…"), makePremise)
			.accessibilityAction(named: Text("Remove link…"), removeLink)
			.accessibilityIdentifier("check.outline.\(id.uuidString)")
	}
}
