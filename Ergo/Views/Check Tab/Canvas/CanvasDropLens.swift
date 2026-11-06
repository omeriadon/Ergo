//
//  CanvasDropLens.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import SwiftUI

/// The card an arrow would make if it was let go here: a little lens under the finger, half the size of a box.
/// `CanvasBoardView` places it and decides when it shows, this only draws it.
struct CanvasDropLens: View {
	static let size = CGSize(width: CanvasLayout.boxSize.width, height: CanvasLayout.boxSize.height)

	let isLifted: Bool

	var body: some View {
		LiquidLens(
			isLifted: isLifted,
			configuration: .init(
				style: 2,
				warpsContentBelow: true,
				restingBackgroundColor: .white.withAlphaComponent(0),
				liftedDisplacement: 70
			)
		)
	}
}
