//
//  CanvasBoardView+Arrows.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoSync
import SwiftUI
import UIKit

extension CanvasBoardView {
	// MARK: - Arrows

	func updateArrows(animation: TimeInterval?) {
		let wanted = Set(links.map(\.id))
		for (id, arrow) in arrows where !wanted.contains(id) {
			arrows[id] = nil
			arrow.removeFromSuperlayer()
			arrowNotes.removeValue(forKey: id)?.removeFromSuperview()
		}
		for link in links {
			update(link, animation: animation)
		}
		styleArrows()
	}

	/// While a box moves, only its own arrows change
	func updateArrows(touching id: Statement.ID, animation: TimeInterval?) {
		for link in links where link.premise == id || link.conclusion == id {
			update(link, animation: animation)
		}
	}

	func update(_ link: Link, animation: TimeInterval?) {
		guard let source = cells[link.premise]?.center, let target = cells[link.conclusion]?.center else { return }

		let arrow: CanvasArrow
		if let existing = arrows[link.id] {
			arrow = existing
		} else {
			arrow = CanvasArrow(in: arrowLayer)
			arrows[link.id] = arrow
		}

		// A box mid-animation already has its final centre here, which is where the arrow should head too
		let curve = ArrowCurve(from: CanvasPoint(source), to: CanvasPoint(target))
		arrow.setPath(curve?.path.cgPath ?? CGMutablePath(), animation: animation)
		updateNote(of: link.id, on: curve, animation: animation)
	}

	/// What an arrow's label says, if it has one. Fine arrows with nothing written about them are left alone.
	private func note(of id: Link.ID) -> (title: String, tint: UIColor)? {
		if let strength = strengths[id], strength == .weak || strength == .none {
			return (strength.label, UIColor(strength.tint))
		}
		return notedLinks.contains(id) ? ("Note", UIColor(Color.accent)) : nil
	}

	/// The label sits halfway along the curve, over the line and under the boxes
	private func updateNote(of id: Link.ID, on curve: ArrowCurve?, animation: TimeInterval?) {
		guard let curve, let style = note(of: id) else {
			arrowNotes.removeValue(forKey: id)?.removeFromSuperview()
			return
		}
		let label: CanvasArrowNote
		if let existing = arrowNotes[id] {
			label = existing
		} else {
			label = CanvasArrowNote { [weak self] in self?.showAnalysis(.link(id)) }
			if let lowest = content.subviews.first {
				content.insertSubview(label, belowSubview: lowest)
			} else {
				content.addSubview(label)
			}
			arrowNotes[id] = label
			label.center = curve.middle
		}
		label.show(title: style.title, tint: style.tint)
		if let animation {
			UIView.animate(springDuration: animation, bounce: 0) {
				label.center = curve.middle
			}
		} else {
			label.center = curve.middle
		}
	}

	func styleArrows() {
		let accent = UIColor(Color.accent).resolvedColor(with: traitCollection)
		let plain = UIColor.secondaryLabel.resolvedColor(with: traitCollection)
		for (id, arrow) in arrows {
			let strengthColor = strengths[id].map { UIColor($0.tint).resolvedColor(with: traitCollection) }
			arrow.style(isSelected: id == selectedLink, accent: accent, plain: plain, strength: strengths[id], strengthColor: strengthColor)
		}
		connection?.arrow.style(isSelected: true, accent: accent, plain: plain)
	}
}
