//
//  CanvasHaptics.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import UIKit

/// What the canvas feels like, read at each tap so the Settings toggle applies at once
final class CanvasHaptics {
	private let gridLine: UIImpactFeedbackGenerator
	private let box: UIImpactFeedbackGenerator

	init(view: UIView) {
		gridLine = UIImpactFeedbackGenerator(style: .light, view: view)
		box = UIImpactFeedbackGenerator(style: .medium, view: view)
	}

	func prepare() {
		guard Defaults[.hapticsEnabled] else { return }
		gridLine.prepare()
		box.prepare()
	}

	func crossedGridLine() {
		guard Defaults[.hapticsEnabled] else { return }
		gridLine.impactOccurred()
	}

	func reachedBox() {
		guard Defaults[.hapticsEnabled] else { return }
		box.impactOccurred()
	}
}
