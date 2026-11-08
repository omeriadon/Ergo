//
//  AccessoryMenuSupport.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ObjectiveC.runtime
import SwiftUI
import UIKit

@available(iOS 26.0, *)
@MainActor
final class AccessoryMenuInteraction: UIContextMenuInteraction {
	var accessoryProvider: ((UIContextMenuConfiguration) -> [UIView])?

	/// Recent UIKit versions leave the private delegate callback unused.
	@objc(_delegate_getAccessoryViewsForConfiguration:)
	func accessoryViews(for configuration: UIContextMenuConfiguration) -> [UIView] {
		accessoryProvider?(configuration) ?? []
	}
}

/// One source view with a tall, scrolling accessory inside the context menu.
@available(iOS 16.0, *)
@MainActor
struct SoftScrollEdgeEffect: ViewModifier {
	func body(content: Content) -> some View {
		if #available(iOS 26.0, *) {
			content.scrollEdgeEffectStyle(.soft, for: .all)
		} else {
			content
		}
	}
}

// One source view with a tall, scrolling accessory inside the context menu.
