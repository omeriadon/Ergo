//
//  CanvasBoardView+ArrowMenu.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

#if os(iOS)
	import ErgoLogic
	import SwiftUI
	import UIKit

	extension CanvasBoardView {
		// MARK: - Arrow menu

		/// A box has its own menu, so this only answers on the background, near an arrow
		func contextMenuInteraction(_: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
			guard !isReadOnly, hitTest(location, with: nil) === self, let id = LinkHitTest.link(
				near: canvasTransform.canvas(location),
				tolerance: 24 / canvasTransform.scale,
				in: links,
				positions: cells.mapValues { CanvasPoint($0.center) }
			) else {
				return nil
			}
			return UIContextMenuConfiguration(identifier: id as NSUUID, previewProvider: nil) { [weak self] _ in
				UIMenu(children: [
					UIAction(title: "Delete Arrow", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
						self?.deleteLink(id)
					},
				])
			}
		}

		func contextMenuInteraction(
			_: UIContextMenuInteraction,
			configuration _: UIContextMenuConfiguration,
			highlightPreviewForItemWithIdentifier identifier: any NSCopying
		) -> UITargetedPreview? {
			arrowPreview(identifier)
		}

		func contextMenuInteraction(
			_: UIContextMenuInteraction,
			configuration _: UIContextMenuConfiguration,
			dismissalPreviewForItemWithIdentifier identifier: any NSCopying
		) -> UITargetedPreview? {
			arrowPreview(identifier)
		}

		/// Just the arrow, drawn on its own. UIKit's preview of a view would lift the whole canvas.
		func arrowPreview(_ identifier: any NSCopying) -> UITargetedPreview? {
			guard let id = identifier as? NSUUID, let path = arrows[id as UUID]?.path else { return nil }

			var toScreen = content.transform
			guard let onScreen = unsafe path.copy(using: &toScreen) else { return nil }
			let frame = onScreen.boundingBoxOfPath.insetBy(dx: -12, dy: -12)

			var toPreview = CGAffineTransform(translationX: -frame.minX, y: -frame.minY)
			let shape = CAShapeLayer()
			shape.path = unsafe onScreen.copy(using: &toPreview)
			shape.fillColor = nil
			shape.strokeColor = UIColor(Color.accent).resolvedColor(with: traitCollection).cgColor
			shape.lineWidth = 3.5
			shape.lineCap = .round

			let preview = UIView(frame: CGRect(origin: .zero, size: frame.size))
			preview.layer.addSublayer(shape)

			let parameters = UIPreviewParameters()
			parameters.backgroundColor = .clear
			return UITargetedPreview(
				view: preview,
				parameters: parameters,
				target: UIPreviewTarget(container: self, center: CGPoint(x: frame.midX, y: frame.midY))
			)
		}
	}
#endif
