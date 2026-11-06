//
//  CanvasBox.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// What a box can do, handed in by the canvas so the box doesn't know about the page or selection
struct BoxActions {
	var select: () -> Void
	var edit: () -> Void
	var delete: () -> Void

	/// Nil without a verdict to show
	var showCheck: (() -> Void)?

	/// Whole grid steps, right and down are positive
	var nudge: (_ columns: Int, _ rows: Int) -> Void
}

/// A statement's box with its taps and VoiceOver. Moving it is done around it by `CanvasBoardView`.
struct CanvasBox: View {
	let model: CanvasBoxModel
	let actions: BoxActions

	private var statement: Statement {
		model.statement
	}

	private var letters: [String] {
		model.letters
	}

	private var relations: BoxRelations {
		model.relations
	}

	private var verdict: BoxVerdict? {
		model.verdict
	}

	private var appearance: BoxAppearance {
		model.appearance
	}

	@Environment(CatalogStore.self)
	private var catalog

	var body: some View {
		box
			.modifier(BoxActionsModifier(actions: actions))
			.modifier(BoxSpeech(text: spokenText, summary: spokenSummary, appearance: appearance, id: statement.id))
			.modifier(BoxMovesModifier(nudge: actions.nudge))
	}

	private var box: some View {
		StatementBoxView(
			statement: statement,
			letters: letters,
			descriptors: model.descriptors,
			relations: relations,
			verdict: verdict,
			appearance: appearance,
			showCheck: { actions.showCheck?() }
		)
		.equatable()
		.onTapGesture(perform: actions.select)
		.simultaneousGesture(TapGesture(count: 2).onEnded(actions.edit))
	}

	// MARK: - Reading aloud

	private var spokenText: String {
		let english = statement.english.trimmingCharacters(in: .whitespacesAndNewlines)
		return english.isEmpty ? StatementBoxView.title(of: statement, letters: letters) : english
	}

	private var spokenSummary: String {
		var parts: [String] = []
		if !relations.premises.isEmpty {
			parts.append("Conclusion of \(relations.premises.formatted(.list(type: .and)))")
		}
		if !relations.conclusions.isEmpty {
			parts.append("Premise of \(relations.conclusions.formatted(.list(type: .and)))")
		}
		if parts.isEmpty {
			parts.append("Not connected")
		}
		if let verdict {
			parts.append("Check: \(verdict.title(in: catalog))")
		}
		if appearance == .connectSource {
			parts.append("Connecting from this statement")
		}
		return parts.joined(separator: ". ")
	}
}

// MARK: - Accessibility

/// Reading the box: its words, how it connects, and that it can be activated
private struct BoxSpeech: ViewModifier {
	let text: String
	let summary: String
	let appearance: BoxAppearance
	let id: Statement.ID

	func body(content: Content) -> some View {
		content
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(text)
			.accessibilityValue(summary)
			.accessibilityHint(appearance == .unavailable ? "Can't be connected to" : "Double tap to select")
			.accessibilityAddTraits(traits)
			.accessibilityIdentifier("check.box.\(id.uuidString)")
	}

	private var traits: AccessibilityTraits {
		appearance == .selected ? [.isButton, .isSelected] : .isButton
	}
}

/// What VoiceOver can do to a box in place of the gestures it can't make
private struct BoxActionsModifier: ViewModifier {
	let actions: BoxActions

	func body(content: Content) -> some View {
		content
			.accessibilityAction(.default, actions.select)
			.accessibilityAction(named: Text("Edit"), actions.edit)
			.accessibilityAction(named: Text("Delete"), actions.delete)
			.accessibilityAction(named: Text("Show check"), showCheck)
	}

	private func showCheck() {
		actions.showCheck?()
	}
}

/// Moving a box a grid step at a time, for people who can't drag
private struct BoxMovesModifier: ViewModifier {
	let nudge: (_ columns: Int, _ rows: Int) -> Void

	func body(content: Content) -> some View {
		content
			.accessibilityAction(named: Text("Move up")) { nudge(0, -1) }
			.accessibilityAction(named: Text("Move down")) { nudge(0, 1) }
			.accessibilityAction(named: Text("Move left")) { nudge(-1, 0) }
			.accessibilityAction(named: Text("Move right")) { nudge(1, 0) }
	}
}
