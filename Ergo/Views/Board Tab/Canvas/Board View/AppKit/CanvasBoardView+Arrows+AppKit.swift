//
//  CanvasBoardView+Arrows+AppKit.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

#if os(macOS)
	import AppKit
	import ErgoLogic
	import ErgoSync
	import SwiftUI

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
		private func note(of id: Link.ID) -> (title: String, tint: NSColor)? {
			if let strength = strengths[id], strength == .weak || strength == .none {
				return (strength.label, NSColor(strength.tint))
			}
			return notedLinks.contains(id) ? ("Note", NSColor(Color.accent)) : nil
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
				// Just above the shapes, so under every box
				content.addSubview(label, positioned: .above, relativeTo: shapes)
				arrowNotes[id] = label
				label.center = curve.middle
			}
			label.show(title: style.title, tint: style.tint)
			if let animation {
				NSAnimationContext.animate(.spring(duration: animation, bounce: 0)) {
					label.setCenter(curve.middle, animated: true)
				}
			} else {
				label.center = curve.middle
			}
		}

		func styleArrows() {
			let accent = accentColor
			let plain = resolved(.secondaryLabelColor)
			for (id, arrow) in arrows {
				let strengthColor = strengths[id].map { resolved(NSColor($0.tint)) }
				arrow.style(
					isSelected: id == selectedLink,
					isHovered: id == hoveredLink,
					accent: accent,
					plain: plain,
					strength: strengths[id],
					strengthColor: strengthColor
				)
			}
			connection?.arrow.style(isSelected: true, accent: accent, plain: plain)
		}

		/// The arrow near a point in this view, the way a click on the background finds one
		func link(near location: CGPoint) -> Link.ID? {
			LinkHitTest.link(
				near: canvasTransform.canvas(location),
				tolerance: 24 / canvasTransform.scale,
				in: links,
				positions: cells.mapValues { CanvasPoint($0.center) }
			)
		}

		// MARK: - Regions

		func updateRegions(animation: TimeInterval?) {
			let wanted = Set(regions.map(\.source))
			for (id, shape) in regionShapes where !wanted.contains(id) {
				regionShapes[id] = nil
				shape.removeFromSuperlayer()
			}
			for region in regions {
				update(region, animation: animation)
			}
			styleRegions()
		}

		/// While a box moves, only the region it's in changes
		func updateRegion(holding id: Statement.ID, animation: TimeInterval?) {
			for region in regions where region.members.contains(id) {
				update(region, animation: animation)
			}
		}

		func updateRegion(of id: BoardSource.ID, animation: TimeInterval?) {
			for region in regions where region.source == id {
				update(region, animation: animation)
			}
		}

		func update(_ region: CanvasRegionModel, animation: TimeInterval?) {
			guard let source = sourceCells[region.source]?.center else { return }

			let shape: CanvasRegionLayer
			if let existing = regionShapes[region.source] {
				shape = existing
			} else {
				shape = CanvasRegionLayer(in: regionLayer)
				regionShapes[region.source] = shape
			}

			let members = region.members.compactMap { cells[$0].map { CanvasPoint($0.center) } }
			let arrows = links.compactMap { link -> CanvasRegion.Arrow? in
				guard region.members.contains(link.premise), region.members.contains(link.conclusion),
				      let from = cells[link.premise]?.center, let to = cells[link.conclusion]?.center
				else { return nil }
				return CanvasRegion.Arrow(from: CanvasPoint(from), to: CanvasPoint(to))
			}
			shape.setOutline(CanvasRegion.outline(source: CanvasPoint(source), members: members, arrows: arrows), animation: animation)
		}

		func styleRegions() {
			// Resolved first, since the shared layer turns it into a CGColor without this view's appearance
			let accent = NSColor(cgColor: accentColor) ?? NSColor(Color.accent)
			for shape in regionShapes.values {
				shape.style(accent: accent)
			}
		}
	}
#endif
