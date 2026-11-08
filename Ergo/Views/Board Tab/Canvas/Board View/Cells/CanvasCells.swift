//
//  CanvasCells.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI
import UIKit

/// SwiftUI for the canvas, in a hosting controller because a hosting configuration can't be told to leave the safe area
/// out. Everything here moves under the bars, and with the safe area in play its content would be laid out again on every
/// frame it's crossing them, which shows as glass moving around. Where things go is `CanvasBoardView`'s business.
func canvasHost<Content: View>(_ content: Content) -> UIHostingController<Content> {
	let host = UIHostingController(rootView: content)
	host.safeAreaRegions = []
	host.view.backgroundColor = .clear
	host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
	return host
}

// MARK: - A box

/// Holds one box's SwiftUI. Its content is only replaced when what it shows changes.
final class CanvasBoxCell: UIView {
	private(set) var model: CanvasBoxModel
	private let isNew: Bool
	private let hosted: UIHostingController<AnyView>

	/// Picked up by a finger
	var isLifted = false {
		didSet {
			layer.shadowOpacity = isLifted ? 0.3 : 0
		}
	}

	/// Starts at its position, so there's never a moment when it's anywhere else
	init(model: CanvasBoxModel, isNew: Bool, content: (CanvasBoxModel, _ isNew: Bool) -> AnyView) {
		self.model = model
		self.isNew = isNew
		hosted = canvasHost(content(model, isNew))
		let box = CanvasRect.box(at: model.statement.position)
		super.init(frame: CGRect(x: box.minX, y: box.minY, width: box.size.width, height: box.size.height))

		hosted.view.frame = bounds
		addSubview(hosted.view)

		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0
		layer.shadowRadius = 12
		layer.shadowOffset = CGSize(width: 0, height: 6)
		layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18).cgPath
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init(model:isNew:content:)")
	}

	func show(_ new: CanvasBoxModel, content: (CanvasBoxModel, _ isNew: Bool) -> AnyView) {
		guard new != model else { return }
		model = new
		hosted.rootView = content(new, isNew)
	}
}

// MARK: - A source

/// Holds one source's SwiftUI, the same way
final class CanvasSourceCell: UIView {
	private(set) var model: CanvasSourceModel
	private let isNew: Bool
	private let hosted: UIHostingController<AnyView>

	/// Picked up by a finger
	var isLifted = false {
		didSet {
			layer.shadowOpacity = isLifted ? 0.3 : 0
		}
	}

	init(model: CanvasSourceModel, isNew: Bool, content: (CanvasSourceModel, _ isNew: Bool) -> AnyView) {
		self.model = model
		self.isNew = isNew
		hosted = canvasHost(content(model, isNew))
		let box = CanvasRect.box(at: model.source.position)
		super.init(frame: CGRect(x: box.minX, y: box.minY, width: box.size.width, height: box.size.height))

		hosted.view.frame = bounds
		addSubview(hosted.view)

		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0
		layer.shadowRadius = 12
		layer.shadowOffset = CGSize(width: 0, height: 6)
		layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18).cgPath
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init(model:isNew:content:)")
	}

	func show(_ new: CanvasSourceModel, content: (CanvasSourceModel, _ isNew: Bool) -> AnyView) {
		guard new != model else { return }
		model = new
		hosted.rootView = content(new, isNew)
	}
}
