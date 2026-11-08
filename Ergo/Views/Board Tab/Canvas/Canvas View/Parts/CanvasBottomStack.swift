//
//  CanvasBottomStack.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

/// The notice and the bar under the canvas, which hide while the editor is on top
struct CanvasBottomStack: View {
	let notice: String?
	let mode: CanvasBarMode
	let actions: CanvasBarActions
	let hasAnnotations: Bool
	let isCovered: Bool
	let motion: Animation?
	let clearNotice: () -> Void

	var body: some View {
		VStack(spacing: 10) {
			if let notice {
				CanvasNoticeView(message: notice, dismiss: clearNotice)
					.transition(.move(edge: .bottom).combined(with: .opacity))
			}

			CanvasBar(mode: mode, actions: actions, hasAnnotations: hasAnnotations)
		}
		.padding(.horizontal, 16)
		.padding(.bottom, 8)
		// The stack is only as wide as what's in it, and the blur goes all the way across
		.frame(maxWidth: .infinity)
		.background(alignment: .bottom) {
			BackdropBlur(radius: 1, fade: .top)
				.ignoresSafeArea(edges: [.horizontal, .bottom])
				.allowsHitTesting(false)
		}
		.opacity(isCovered ? 0 : 1)
		.allowsHitTesting(!isCovered)
		.animation(motion, value: notice)
		.animation(.easeOut(duration: 0.15), value: isCovered)
	}
}
