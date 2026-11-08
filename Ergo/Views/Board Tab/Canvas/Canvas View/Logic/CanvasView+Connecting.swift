//
//  CanvasView+Connecting.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoSync
import SwiftUI

extension CanvasView {
	// MARK: - Connecting

	func connectStarted(_ id: Statement.ID, asConclusion: Bool) {
		selection = .statement(id)
		connectsAsConclusion = asConclusion
		connecting = id
	}

	/// Let go over a box, the arrow is drawn or the notice says why not. Let go on empty canvas, a new box goes there.
	func connectEnded(_ source: Statement.ID, drop: ConnectionDrop) {
		connecting = nil
		connectTarget = nil
		switch drop {
			case let .box(target):
				let new = newLink(from: source, to: target)
				link(premise: new.premise, conclusion: new.conclusion)
			case let .space(point):
				addLinked(to: source, near: point)
			case .nowhere:
				break
		}
	}

	/// A new empty box where the arrow was let go, which is a premise of `source` when the arrow came out of the top of
	/// it, and a conclusion when it came out of the bottom
	func addLinked(to source: Statement.ID, near point: CanvasPoint) {
		guard board.statements.count < ArgumentMapValidator.defaultMaximumStatements else {
			show(statementLimitMessage)
			return
		}

		let side: CanvasLayout.Side = connectsAsConclusion ? .above : .below
		history.perform(connectsAsConclusion ? "Add Premise" : "Add Conclusion") {
			withAnimation(motion) {
				guard let new = boardStore.addStatement(at: freeSpot(near: point, side: side)) else { return }
				let arrow = newLink(from: source, to: new)
				boardStore.link(premise: arrow.premise, conclusion: arrow.conclusion)
				selection = .statement(new)
			}
		}
		keepsFitting = false
	}

	/// The arrow for dragging from `source` to `target`, which way round depending on the handle it came from
	func newLink(from source: Statement.ID, to target: Statement.ID) -> Link {
		connectsAsConclusion
			? Link(premise: target, conclusion: source)
			: Link(premise: source, conclusion: target)
	}

	/// True when the arrow was drawn, otherwise says why not
	@discardableResult
	func link(premise: Statement.ID, conclusion: Statement.ID) -> Bool {
		var problem: ArgumentMapProblem?
		history.perform("Add Link") {
			withAnimation(motion) {
				problem = boardStore.link(premise: premise, conclusion: conclusion)
			}
		}
		if let problem {
			show(linkMessage(for: problem, premise: premise, conclusion: conclusion))
		}
		return problem == nil
	}

	/// Why an arrow wasn't drawn, the way a person would say it rather than in the validator's words. An arrow back
	/// along an existing one counts as a loop to the validator, but all anyone sees is two cards already connected.
	func linkMessage(for problem: ArgumentMapProblem, premise: Statement.ID, conclusion: Statement.ID) -> String {
		let isReversed = board.links.contains { $0.premise == conclusion && $0.conclusion == premise }
		return switch problem {
			case .duplicateLink:
				"These cards are already connected"
			case .cycle where isReversed:
				"These cards are already connected"
			case .cycle:
				"That would make a loop, so these cards can't be connected"
			case .selfLink:
				"A card can't connect to itself"
			case .danglingLink:
				"That card isn't on this board anymore"
			default:
				problem.message
		}
	}

	// MARK: - Picking

	func pickToConnect(_ id: Statement.ID, asConclusion: Bool) {
		connectsAsConclusion = asConclusion
		start(.connect(id))
	}

	func pickToUnlink(_ id: Statement.ID) {
		start(.unlink(id))
	}

	func start(_ new: BoxPick) {
		selection = .statement(new.source)
		pick = new
		AccessibilityNotification.Announcement(prompt(for: new)).post()
	}

	func prompt(for pick: BoxPick) -> String {
		switch pick {
			case .connect: connectsAsConclusion ? "Tap its premise" : "Tap its conclusion"
			case .unlink: "Tap the linked statement"
		}
	}

	/// The box itself cancels. A box that can't be the answer leaves the pick open, so another can be tapped.
	func finish(_ pick: BoxPick, with id: Statement.ID) {
		guard id != pick.source else {
			self.pick = nil
			return
		}

		switch pick {
			case let .connect(source):
				let new = newLink(from: source, to: id)
				if link(premise: new.premise, conclusion: new.conclusion) {
					self.pick = nil
				}
			case let .unlink(source):
				let arrow = board.links.first { ($0.premise == source && $0.conclusion == id) || ($0.premise == id && $0.conclusion == source) }
				if let arrow {
					deleteLink(arrow.id)
					self.pick = nil
				}
		}
	}
}
