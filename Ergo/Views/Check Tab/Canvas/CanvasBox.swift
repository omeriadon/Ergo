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
	/// Select it, or finish an arrow when connecting
	var select: () -> Void
	var edit: () -> Void
	var connect: () -> Void
	var delete: () -> Void

	/// Nil without a verdict to show
	var showCheck: (() -> Void)?

	/// Whole grid steps, right and down are positive
	var nudge: (_ columns: Int, _ rows: Int) -> Void
}

/// A statement's box with everything the canvas needs around it: its place, gestures, the zoom transition's source
/// and VoiceOver. Dragging reports in the canvas's own coordinate space, because the box itself moves.
struct CanvasBox: View {
	let statement: Statement
	let letters: [String]
	let descriptors: [String]
	let relations: BoxRelations
	let verdict: BoxVerdict?
	let appearance: BoxAppearance
	let isDragging: Bool

	/// Where the centre of the box is right now
	let position: CanvasPoint

	let zoomNamespace: Namespace.ID
	let actions: BoxActions

	/// Translation so far in screen points, from the start of the drag
	let dragChanged: (CGSize) -> Void
	let dragEnded: (CGSize) -> Void

	@Environment(CatalogStore.self)
	private var catalog

	var body: some View {
		box
			.modifier(BoxActionsModifier(actions: actions))
			.modifier(BoxSpeech(text: spokenText, summary: spokenSummary, appearance: appearance, id: statement.id))
			.modifier(BoxMovesModifier(nudge: actions.nudge))
			// After the accessibility modifiers, so VoiceOver's frame is the box and not the whole canvas that `position` fills
			.position(x: position.x, y: position.y)
	}

	private var box: some View {
		StatementBoxView(
			statement: statement,
			letters: letters,
			descriptors: descriptors,
			relations: relations,
			verdict: verdict,
			appearance: appearance,
			showCheck: { actions.showCheck?() }
		)
		.equatable()
		.shadow(color: .black.opacity(isDragging ? 0.3 : 0), radius: 12, y: 6)
		.matchedTransitionSource(id: statement.id, in: zoomNamespace)
		.onTapGesture(perform: actions.select)
		.simultaneousGesture(TapGesture(count: 2).onEnded(actions.edit))
		.gesture(drag)
	}

	/// In the canvas's space, which holds still while the box moves under the finger
	private var drag: some Gesture {
		DragGesture(minimumDistance: 6, coordinateSpace: .named(CanvasCoordinateSpace.name))
			.onChanged { dragChanged($0.translation) }
			.onEnded { dragEnded($0.translation) }
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
			.accessibilityAction(named: Text("Connect to…"), actions.connect)
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
