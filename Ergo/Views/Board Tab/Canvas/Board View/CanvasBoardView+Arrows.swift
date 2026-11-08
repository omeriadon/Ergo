//
//  CanvasBoardView+Arrows.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI
import UIKit

extension CanvasBoardView {
	// MARK: - Arrows

	func updateArrows(animation: TimeInterval?) {
		let wanted = Set(links.map(\.id))
		for (id, arrow) in arrows where !wanted.contains(id) {
			arrows[id] = nil
			arrow.removeFromSuperlayer()
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
		let path = ArrowCurve(from: CanvasPoint(source), to: CanvasPoint(target))?.path.cgPath ?? CGMutablePath()
		arrow.setPath(path, animation: animation)
	}

	func styleArrows() {
		let accent = UIColor(Color.accent).resolvedColor(with: traitCollection)
		let plain = UIColor.secondaryLabel.resolvedColor(with: traitCollection)
		for (id, arrow) in arrows {
			arrow.style(isSelected: id == selectedLink, accent: accent, plain: plain)
		}
		connection?.arrow.style(isSelected: true, accent: accent, plain: plain)
	}
}
