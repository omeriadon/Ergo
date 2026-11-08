//
//  CanvasBox.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// What a box can do, handed in by the canvas so the box doesn't know about the board or selection
struct BoxActions {
	var select: () -> Void
	var edit: () -> Void
	var delete: () -> Void

	/// The next box tapped is the other end of a new arrow
	var connect: (_ asConclusion: Bool) -> Void

	/// The next box tapped loses its arrow to or from this one
	var removeLink: () -> Void

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

	private var relations: BoxRelations {
		model.relations
	}

	private var appearance: BoxAppearance {
		model.appearance
	}

	var body: some View {
		box
			.modifier(BoxActionsModifier(actions: actions, isReadOnly: model.isReadOnly))
			.modifier(BoxSpeech(text: spokenText, summary: spokenSummary, appearance: appearance, id: statement.id))
			.modifier(BoxMovesModifier(nudge: actions.nudge, isReadOnly: model.isReadOnly))
	}

	private var box: some View {
		StatementBoxView(
			statement: statement,
			relations: relations,
			appearance: appearance,
			annotationCount: model.annotationCount
		)
		.equatable()
		.onTapGesture(perform: actions.select)
		.simultaneousGesture(TapGesture(count: 2).onEnded(actions.edit))
		.contextMenu { menu }
	}

	@ViewBuilder
	private var menu: some View {
		if model.isReadOnly {
			Button("Open", systemImage: "doc.text", action: actions.edit)
		} else {
			Button("Edit", systemImage: "square.and.pencil", action: actions.edit)
			Button("Make Premise of…", systemImage: "arrow.down") { actions.connect(false) }
			Button("Make Conclusion of…", systemImage: "arrow.up") { actions.connect(true) }
			if !relations.premises.isEmpty || !relations.conclusions.isEmpty {
				Button("Remove Link…", systemImage: "link", action: actions.removeLink)
			}
			Button("Delete", systemImage: "trash", role: .destructive, action: actions.delete)
		}
	}

	// MARK: - Reading aloud

	private var spokenText: String {
		let english = statement.english.trimmingCharacters(in: .whitespacesAndNewlines)
		return english.isEmpty ? StatementBoxView.title(of: statement) : english
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
		if model.annotationCount > 0 {
			parts.append(model.annotationCount == 1 ? "1 annotation" : "\(model.annotationCount) annotations")
		}
		if appearance == .connectSource {
			parts.append("Connecting from this statement")
		}
		return parts.joined(separator: ". ")
	}
}

// MARK: - Arriving

/// A box that was just added comes into focus. One that was already on the board just shows.
struct BoxEntrance: ViewModifier {
	let isNew: Bool

	@State private var hasArrived = false

	private var isHidden: Bool {
		isNew && !hasArrived
	}

	func body(content: Content) -> some View {
		content
			.blur(radius: isHidden ? 10 : 0)
			.opacity(isHidden ? 0 : 1)
			.onAppear {
				guard isNew else { return }
				withAnimation(.smooth) {
					hasArrived = true
				}
			}
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
			.accessibilityIdentifier("board.box.\(id.uuidString)")
	}

	private var traits: AccessibilityTraits {
		appearance == .selected ? [.isButton, .isSelected] : .isButton
	}
}

/// What VoiceOver can do to a box in place of the gestures it can't make
private struct BoxActionsModifier: ViewModifier {
	let actions: BoxActions
	let isReadOnly: Bool

	func body(content: Content) -> some View {
		if isReadOnly {
			content
				.accessibilityAction(.default, actions.select)
				.accessibilityAction(named: Text("Open"), actions.edit)
		} else {
			content
				.accessibilityAction(.default, actions.select)
				.accessibilityAction(named: Text("Edit"), actions.edit)
				.accessibilityAction(named: Text("Make premise of…")) { actions.connect(false) }
				.accessibilityAction(named: Text("Make conclusion of…")) { actions.connect(true) }
				.accessibilityAction(named: Text("Remove link…"), actions.removeLink)
				.accessibilityAction(named: Text("Delete"), actions.delete)
		}
	}
}

/// Moving a box a grid step at a time, for people who can't drag
struct BoxMovesModifier: ViewModifier {
	let nudge: (_ columns: Int, _ rows: Int) -> Void
	let isReadOnly: Bool

	func body(content: Content) -> some View {
		if isReadOnly {
			content
		} else {
			content
				.accessibilityAction(named: Text("Move up")) { nudge(0, -1) }
				.accessibilityAction(named: Text("Move down")) { nudge(0, 1) }
				.accessibilityAction(named: Text("Move left")) { nudge(-1, 0) }
				.accessibilityAction(named: Text("Move right")) { nudge(1, 0) }
		}
	}
}
