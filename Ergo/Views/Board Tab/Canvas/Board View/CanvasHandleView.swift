//
//  CanvasHandleView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI
import UIKit

/// Holds `CanvasConnectHandle`'s SwiftUI
final class CanvasHandleView: UIView {
	let isAbove: Bool
	private let hosted: UIHostingController<AnyView>

	init(isAbove: Bool, content: (_ pointsUp: Bool) -> AnyView) {
		self.isAbove = isAbove
		hosted = canvasHost(content(isAbove))
		let size = CanvasConnectHandle.size
		super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))

		hosted.view.frame = bounds
		addSubview(hosted.view)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("Use init(isAbove:content:)")
	}
}
